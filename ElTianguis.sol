// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Morralla.sol";
import "./SafeBEP20.sol";
import "./Micheladas.sol";


contract ElTianguis is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for BEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of MRRLLA
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accMorrallaPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accMorrallaPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. MRRLLA to distribute per block.
        uint256 lastRewardBlock;  // Last block number that MRRLLA distribution occurs.
        uint256 accMorrallaPerShare; // Accumulated MRRLLA per share, times 1e12. See below.
    }

    //  Tokens
    Morralla public morralla;
    Micheladas public micheladas;
    // farm parameters
    address public devAddr;
    uint256 public morrallaPerBlock;
    uint256 public BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when MRRLL mining starts.
    uint256 public startBlock;

    // vars and modifier for reentry guard prevention
    mapping (address => uint) internal lastBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        Morralla _morralla,
        Micheladas _micheladas,
        address _devAddr,
        uint256 _morrallaPerBlock,
        uint256 _startBlock
    )  {
        morralla = _morralla;
        micheladas = _micheladas;
        devAddr = _devAddr;
        morrallaPerBlock = _morrallaPerBlock;
        startBlock = _startBlock;

        // staking pool
        poolInfo.push(PoolInfo({
            lpToken: _morralla,
            allocPoint: 100,
            lastRewardBlock: startBlock,
            accMorrallaPerShare: 0
        }));

        totalAllocPoint = 100;

    }

    function _notSameBlock() internal {
        require(
        block.number > lastBlock[_msgSender()],
        "Can't carry out actions in the same block"
        );
        lastBlock[_msgSender()] = block.number;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accMorrallaPerShare: 0
        }));
    }

    // Update the given pool's MRRLL allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending MORRALLA on frontend.
    function pendingMorralla(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accMorrallaPerShare = pool.accMorrallaPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 morrallaReward = multiplier.mul(morrallaPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accMorrallaPerShare = accMorrallaPerShare.add(morrallaReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accMorrallaPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 morrallaReward = multiplier.mul(morrallaPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        morralla.mint(devAddr, morrallaReward.div(10));
        morralla.mint(address(micheladas), morrallaReward.sub(morrallaReward.div(10)));
        pool.accMorrallaPerShare = pool.accMorrallaPerShare.add(morrallaReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to Tianguis! for MRRLL allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        _notSameBlock();
        require (_pid != 0, 'deposit MRRLL by staking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accMorrallaPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeMorrallaTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
            user.rewardDebt = user.amount.mul(pool.accMorrallaPerShare).div(1e12);
            emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from Tianguis!
    function withdraw(uint256 _pid, uint256 _amount) public {
        _notSameBlock();
        require (_pid != 0, 'withdraw MRRLL by unstaking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: amount exceed deposited");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accMorrallaPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            user.rewardDebt = user.amount.mul(pool.accMorrallaPerShare).div(1e12);
            safeMorrallaTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.transfer(address(msg.sender), _amount);
        }
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // solo harvest
    function harvest(uint256 _pid) public  {
        _notSameBlock();
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accMorrallaPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            user.rewardDebt = user.amount.mul(pool.accMorrallaPerShare).div(1e12);
            safeMorrallaTransfer(msg.sender, pending);
        }
    }
    
    // Stake MRRLL tokens to Tianguis!
    function enterMicheladas(uint256 _amount) public {
        _notSameBlock();
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
 
         if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accMorrallaPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeMorrallaTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accMorrallaPerShare).div(1e12);
        
        micheladas.mint(msg.sender, _amount);
        emit Deposit(msg.sender, 0, _amount);
    }

    // Withdraw MRRLL tokens from STAKING.
    function leaveMicheladas(uint256 _amount) public {
        _notSameBlock();
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "you don't have enough micheladas");
        updatePool(0);
        uint256 pending = user.amount.mul(pool.accMorrallaPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeMorrallaTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.transfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accMorrallaPerShare).div(1e12);
        
        micheladas.burn(msg.sender, _amount);
        emit Withdraw(msg.sender, 0, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        require (_pid != 0, "Usa leaveMicheladas");
        _notSameBlock();
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.transfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe morralla transfer function, just in case if rounding error causes pool to not have enough MRRLLA.
    function safeMorrallaTransfer(address _to, uint256 _amount) internal {
        micheladas.safeMorrallaTransfer(_to, _amount);
    }

    // Update dev address
    function dev(address _devAddr) public onlyOwner {
        devAddr = _devAddr;
    }
}