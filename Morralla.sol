//                                                                       ,--,      ,--,                   
//           ____      ,----..                                        ,---.'|   ,---.'|                   
//         ,'  , `.   /   /   \  ,-.----.   ,-.----.      ,---,       |   | :   |   | :      ,---,        
//      ,-+-,.' _ |  /   .     : \    /  \  \    /  \    '  .' \      :   : |   :   : |     '  .' \       
//   ,-+-. ;   , || .   /   ;.  \;   :    \ ;   :    \  /  ;    '.    |   ' :   |   ' :    /  ;    '.     
//  ,--.'|'   |  ;|.   ;   /  ` ;|   | .\ : |   | .\ : :  :       \   ;   ; '   ;   ; '   :  :       \    
// |   |  ,', |  ':;   |  ; \ ; |.   : |: | .   : |: | :  |   /\   \  '   | |__ '   | |__ :  |   /\   \   
// |   | /  | |  |||   :  | ; | '|   |  \ : |   |  \ : |  :  ' ;.   : |   | :.'||   | :.'||  :  ' ;.   :  
// '   | :  | :  |,.   |  ' ' ' :|   : .  / |   : .  / |  |  ;/  \   \'   :    ;'   :    ;|  |  ;/  \   \ 
// ;   . |  ; |--' '   ;  \; /  |;   | |  \ ;   | |  \ '  :  | \  \ ,'|   |  ./ |   |  ./ '  :  | \  \ ,' 
// |   : |  | ,     \   \  ',  / |   | ;\  \|   | ;\  \|  |  '  '--'  ;   : ;   ;   : ;   |  |  '  '--'   
// |   : '  |/       ;   :    /  :   ' | \.':   ' | \.'|  :  :        |   ,/    |   ,/    |  :  :         
// ;   | |`-'         \   \ .'   :   : :-'  :   : :-'  |  | ,'        '---'     '---'     |  | ,'         
// |   ;/              `---`     |   |.'    |   |.'    `--''                              `--''           
// '---'                         `---'      `---'                                                         
// MORRALLA EL TOKEN DE TIANGUIS.FINANCE 
// Saludos a Theo el legendario y a Zky: chido por el paro
// - Chanclas

pragma solidity ^0.8.4;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BEP20.sol";

contract Morralla is BEP20('Morralla', 'MRRLL') {
    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner.
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function burn(uint256 _amount) public {
        _burn( _msgSender(), _amount);
    }
}
