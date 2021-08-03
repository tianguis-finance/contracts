// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Micheladas.sol";
import "./Morralla.sol";

contract ElTianguis is Ownable {

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of MORRALLA
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
        IERC20 lpToken;           // Address of (LP) token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. MORRALLA to distribute per block.
        uint256 lastRewardBlock;  // Last block number that MORRALLA distribution occurs.
        uint256 accMorrallaPerShare; // Accumulated MORRALLA per share, times 1e12. See below.
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
    // The block number when MORRALLA mining starts.
    uint256 public startBlock;

    // vars and modifier for reentry guard prevention
    mapping (address => uint) internal lastBlock;
    uint private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, 'TIANGUIS: CERRADA');
        unlocked = 0;
        _;
        unlocked = 1;
    }

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

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accMorrallaPerShare: 0
        }));
    }

    // Update the given pool's MORRALLA allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to - _from * BONUS_MULTIPLIER;
    }

    // View function to see pending MORRALLA on frontend.
    function pendingMorralla(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accMorrallaPerShare = pool.accMorrallaPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 morrallaReward = multiplier * morrallaPerBlock * pool.allocPoint / totalAllocPoint;
            accMorrallaPerShare = accMorrallaPerShare + morrallaReward * 1e12 / lpSupply;
        }
        return user.amount * accMorrallaPerShare / 1e12 - user.rewardDebt;
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
        uint256 morrallaReward = multiplier * morrallaPerBlock * pool.allocPoint / totalAllocPoint;
        morralla.mint(devAddr, morrallaReward / 10);
        morralla.mint(address(micheladas), morrallaReward - morrallaReward / 10);
        pool.accMorrallaPerShare = pool.accMorrallaPerShare + morrallaReward * 1e12 / lpSupply;
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to Tianguis! for MORRALLA allocation.
    function deposit(uint256 _pid, uint256 _amount) public lock {
        require (_pid != 0, 'deposit MORRALLA by staking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount * pool.accMorrallaPerShare / 1e12 - user.rewardDebt;
            if(pending > 0) {
                safeMorrallaTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount + _amount;
        }
            user.rewardDebt = user.amount * pool.accMorrallaPerShare / 1e12;
            emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from Tianguis!
    function withdraw(uint256 _pid, uint256 _amount) public lock {
        require (_pid != 0, 'withdraw MORRALLA by unstaking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: amount exceed deposited");

        updatePool(_pid);
        uint256 pending = user.amount * pool.accMorrallaPerShare / 1e12 - user.rewardDebt;
        if(pending > 0) {
            user.rewardDebt = user.amount * pool.accMorrallaPerShare / 1e12;
            safeMorrallaTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount - _amount;
            pool.lpToken.transfer(address(msg.sender), _amount);
        }
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // solo harvest
    function harvest(uint256 _pid) public  {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        uint256 pending = user.amount * pool.accMorrallaPerShare / 1e12 - user.rewardDebt;
        if(pending > 0) {
            user.rewardDebt = user.amount * pool.accMorrallaPerShare / 1e12;
            safeMorrallaTransfer(msg.sender, pending);
        }
    }
    
    // Stake MORRALLA tokens to Tianguis!
    function enterMicheladas(uint256 _amount) public lock {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
 
         if (user.amount > 0) {
            uint256 pending = user.amount * pool.accMorrallaPerShare / 1e12 - user.rewardDebt;
            if(pending > 0) {
                safeMorrallaTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount + _amount;
        }
        user.rewardDebt = user.amount * pool.accMorrallaPerShare / 1e12;
        
        micheladas.mint(msg.sender, _amount);
        emit Deposit(msg.sender, 0, _amount);
    }

    // Withdraw MORRALLA tokens from STAKING.
    function leaveMicheladas(uint256 _amount) public lock {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "you don't have enough micheladas");
        updatePool(0);
        uint256 pending = user.amount * pool.accMorrallaPerShare / 1e12 - user.rewardDebt;
        if(pending > 0) {
            safeMorrallaTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount - _amount;
            pool.lpToken.transfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount * pool.accMorrallaPerShare / 1e12;
        
        micheladas.burn(msg.sender, _amount);
        emit Withdraw(msg.sender, 0, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        require (_pid != 0, "Use leaveMicheladas");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.transfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe morralla transfer function, just in case if rounding error causes pool to not have enough MORRALLA.
    function safeMorrallaTransfer(address _to, uint256 _amount) internal {
        micheladas.safeMorrallaTransfer(_to, _amount);
    }

    // Update dev address
    function dev(address _devAddr) public onlyOwner {
        devAddr = _devAddr;
    }
}