pragma solidity ^0.8.4;
import "./BEP20.sol";
import "./Morralla.sol";

contract Micheladas is BEP20('Michelada', 'MICHELADA') {
    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (El Tianguis).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function burn(address _from ,uint256 _amount) public onlyOwner {
        _burn(_from, _amount);
    }

    // Morralla
    Morralla public morralla;

    constructor(
        Morralla _morralla
    )  {
        morralla = _morralla;
    }

    // Safe morralla transfer function, just in case if rounding error causes pool to not have enough MORRALLA.
    function safeMorrallaTransfer(address _to, uint256 _amount) public onlyOwner {
        uint256 morrallaBal = morralla.balanceOf(address(this));
        if (_amount > morrallaBal) {
            morralla.transfer(_to, morrallaBal);
        } else {
            morralla.transfer(_to, _amount);
        }
    }
}