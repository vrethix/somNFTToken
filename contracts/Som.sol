/**
 *Submitted for verification at BscScan.com on 2022-05-07
*/

// SPDX-License-Identifier: NOLICENSE
pragma solidity 0.8.4;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

interface IAntisnipe {
    function assureCanTransfer(
        address sender,
        address from,
        address to,
        uint256 amount
    ) external returns (bool response);
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _setOwner(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), 'Ownable: caller is not the owner');
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), 'Ownable: new owner is the zero address');
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract SoulsOfMeta is Context, IERC20, Ownable {
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;

    address[] private _excluded;

    bool public tradingEnabled;
    bool public swapEnabled;
    bool private swapping;

    IRouter public router;
    address public pair;

    uint8 private constant _decimals = 9;
    uint256 private constant MAX = ~uint256(0);

    uint256 private _tTotal = 3e9 * 10**_decimals;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));

    struct UserLastSell {
        uint256 amountSoldInCycle;
        uint256 lastSellTime;
    }
    mapping(address => UserLastSell) public userLastSell;

    address public stakingAddress = 0x05Ad5Eb358A4e31408c9Bb080D3ebE2f62b67088;
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;
    address public communityAddress = 0x9cB3d1fA2aE9f66d7d65ACf3bd34eF79C5F6c20d;

    string private constant _name = 'Souls Of Meta';
    string private constant _symbol = 'SOM';

    struct Taxes {
        uint256 rfi;
        uint256 staking;
        uint256 liquidity;
        uint256 burn;
        uint256 community;
    }

    Taxes public taxes = Taxes(0, 0, 0, 0, 0);
    Taxes public buyTaxes = Taxes(0, 0, 0, 0, 0);
    Taxes public sellTaxes = Taxes(0, 0, 0, 0, 0);

    struct TotFeesPaidStruct {
        uint256 rfi;
        uint256 staking;
        uint256 liquidity;
        uint256 burn;
        uint256 community;
    }
    TotFeesPaidStruct public totFeesPaid;

    struct valuesFromGetValues {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rRfi;
        uint256 rStaking;
        uint256 rLiquidity;
        uint256 rBurn;
        uint256 rCommunity;
        uint256 tTransferAmount;
        uint256 tRfi;
        uint256 tStaking;
        uint256 tLiquidity;
        uint256 tBurn;
        uint256 tCommunity;
    }

    event FeesChanged();
    event UpdatedRouter(address oldRouter, address newRouter);

    modifier lockTheSwap() {
        swapping = true;
        _;
        swapping = false;
    }

    constructor(address routerAddress) {
        IRouter _router = IRouter(routerAddress);
        address _pair = IFactory(_router.factory()).createPair(
            address(this),
            _router.WETH()
        );

        router = _router;
        pair = _pair;

        excludeFromReward(pair);
        excludeFromReward(deadAddress);

        _rOwned[owner()] = _rTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[stakingAddress] = false;
        _isExcludedFromFee[deadAddress] = false;
        _isExcludedFromFee[communityAddress] = false;

        emit Transfer(address(0), owner(), _tTotal);
    }

    //std ERC20:
    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    //override ERC20:
    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, 'ERC20: transfer amount exceeds allowance');
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            'ERC20: decreased allowance below zero'
        );
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferRfi)
        public
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, 'Amount must be less than supply');
        if (!deductTransferRfi) {
            valuesFromGetValues memory s = _getValues(tAmount, true, 3);
            return s.rAmount;
        } else {
            valuesFromGetValues memory s = _getValues(tAmount, true, 3);
            return s.rTransferAmount;
        }
    }

    function setTradingStatus(bool state) external onlyOwner {
        tradingEnabled = state;
        swapEnabled = state;
    }

    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        require(rAmount <= _rTotal, 'Amount must be less than total reflections');
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    //@dev kept original RFI naming -> "reward" as in reflection
    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], 'Account is already excluded');
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], 'Account is not excluded');
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function setTaxes(
        uint256 _rfi,
        uint256 _staking,
        uint256 _community,
        uint256 _liquidity,
        uint256 _burn
    ) public onlyOwner {
        require(
            _rfi + _staking + _liquidity + _community + _burn <= 12,
            'Fees must be lower than 12%'
        );
        taxes.rfi = _rfi;
        taxes.staking = _staking;
        taxes.liquidity = _liquidity;
        taxes.burn = _burn;
        taxes.community = _community;
        emit FeesChanged();
    }

    function setBuyTaxes(
        uint256 _rfi,
        uint256 _staking,
        uint256 _community,
        uint256 _liquidity,
        uint256 _burn
    ) public onlyOwner {
        require(
            _rfi + _staking + _community + _liquidity + _burn <= 12,
            'Fees must be lower than 12%'
        );
        buyTaxes.rfi = _rfi;
        buyTaxes.staking = _staking;
        buyTaxes.liquidity = _liquidity;
        buyTaxes.burn = _burn;
        buyTaxes.community = _community;
        emit FeesChanged();
    }

    function setSellTaxes(
        uint256 _rfi,
        uint256 _staking,
        uint256 _community,
        uint256 _liquidity,
        uint256 _burn
    ) public onlyOwner {
        require(
            _rfi + _staking + _liquidity + _burn <= 12,
            'Fees must be lower than 12%'
        );
        sellTaxes.rfi = _rfi;
        sellTaxes.staking = _staking;
        sellTaxes.liquidity = _liquidity;
        sellTaxes.burn = _burn;
        sellTaxes.community = _community;
        emit FeesChanged();
    }

    function _reflectRfi(uint256 rRfi, uint256 tRfi) private {
        _rTotal -= rRfi;
        totFeesPaid.rfi += tRfi;
    }

    function _takeLiquidity(uint256 rLiquidity, uint256 tLiquidity) private {
        totFeesPaid.liquidity += tLiquidity;

        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] += tLiquidity;
        }
        _rOwned[address(this)] += rLiquidity;
    }

    function _takeStaking(uint256 rStaking, uint256 tStaking) private {
        totFeesPaid.staking += tStaking;

        if (_isExcluded[stakingAddress]) {
            _tOwned[stakingAddress] += tStaking;
        }
        _rOwned[stakingAddress] += rStaking;
    }

    function _takeCommunity(uint256 rCommunity, uint256 tCommunity) private {
        totFeesPaid.community += tCommunity;

        if (_isExcluded[communityAddress]) {
            _tOwned[communityAddress] += tCommunity;
        }
        _rOwned[communityAddress] += rCommunity;
    }

    function _takeBurn(uint256 rBurn, uint256 tBurn) private {
        totFeesPaid.burn += tBurn;

        if (_isExcluded[deadAddress]) {
            _tOwned[deadAddress] += tBurn;
        }
        _rOwned[deadAddress] += rBurn;
    }

    function _getValues(
        uint256 tAmount,
        bool takeFee,
        uint8 category
    ) private view returns (valuesFromGetValues memory to_return) {
        to_return = _getTValues(tAmount, takeFee, category);
        (
            to_return.rAmount,
            to_return.rTransferAmount,
            to_return.rRfi,
            to_return.rStaking,
            to_return.rCommunity,
            to_return.rLiquidity,
            to_return.rBurn
        ) = _getRValues(to_return, tAmount, takeFee, _getRate());
        return to_return;
    }

    function _getTValues(
        uint256 tAmount,
        bool takeFee,
        uint8 category
    ) private view returns (valuesFromGetValues memory s) {
        if (!takeFee) {
            s.tTransferAmount = tAmount;
            return s;
        }
        Taxes memory temp;
        if (category == 0) temp = sellTaxes;
        else if (category == 1) temp = buyTaxes;
        else temp = taxes;

        s.tRfi = (tAmount * temp.rfi) / 100;
        s.tStaking = (tAmount * temp.staking) / 100;
        s.tCommunity = (tAmount * temp.community) / 100;
        s.tLiquidity = (tAmount * temp.liquidity) / 100;
        s.tBurn = (tAmount * temp.burn) / 100;
        s.tTransferAmount =
            tAmount -
            s.tRfi -
            s.tStaking -
            s.tCommunity -
            s.tLiquidity -
            s.tBurn;
        return s;
    }

    function _getRValues(
        valuesFromGetValues memory s,
        uint256 tAmount,
        bool takeFee,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rRfi,
            uint256 rStaking,
            uint256 rCommunity,
            uint256 rLiquidity,
            uint256 rBurn
        )
    {
        rAmount = tAmount * currentRate;

        if (!takeFee) {
            return (rAmount, rAmount, 0, 0, 0, 0, 0);
        }

        rRfi = s.tRfi * currentRate;
        rStaking = s.tStaking * currentRate;
        rLiquidity = s.tLiquidity * currentRate;
        rBurn = s.rBurn * currentRate;
        rCommunity = s.tCommunity * currentRate;
        rTransferAmount = rAmount - rRfi - rStaking - rLiquidity - rCommunity - rBurn;
        return (rAmount, rTransferAmount, rRfi, rStaking, rLiquidity, rCommunity, rBurn);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply)
                return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), 'ERC20: approve from the zero address');
        require(spender != address(0), 'ERC20: approve to the zero address');
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), 'ERC20: transfer from the zero address');
        require(to != address(0), 'ERC20: transfer to the zero address');
        require(amount > 0, 'Transfer amount must be greater than zero');
        require(
            amount <= balanceOf(from),
            'You are trying to transfer more than your balance'
        );

        _beforeTokenTransfer(from, to, amount);

        uint8 category;
        if (to == pair)
            category = 0; // 0 --> SELL
        else if (from == pair)
            category = 1; // 1 --> BUY
        else if (from != pair && to != pair) category = 2; // 2 --> TRANSFER

        _tokenTransfer(
            from,
            to,
            amount,
            !(_isExcludedFromFee[from] || _isExcludedFromFee[to]),
            category
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee,
        uint8 category
    ) private {
        valuesFromGetValues memory s = _getValues(tAmount, takeFee, category);

        if (_isExcluded[sender]) {
            //from excluded
            _tOwned[sender] = _tOwned[sender] - tAmount;
        }
        if (_isExcluded[recipient]) {
            //to excluded
            _tOwned[recipient] = _tOwned[recipient] + s.tTransferAmount;
        }

        _rOwned[sender] = _rOwned[sender] - s.rAmount;
        _rOwned[recipient] = _rOwned[recipient] + s.rTransferAmount;

        if (s.rRfi > 0 || s.tRfi > 0) _reflectRfi(s.rRfi, s.tRfi);
        if (s.rLiquidity > 0 || s.tLiquidity > 0) {
            _takeLiquidity(s.rLiquidity, s.tLiquidity);
            emit Transfer(sender, address(this), s.tLiquidity);
        }
        if (s.rStaking > 0 || s.tStaking > 0) {
            _takeStaking(s.rStaking, s.tStaking);
            emit Transfer(sender, stakingAddress, s.tStaking);
        }
        if (s.rCommunity > 0 || s.tCommunity > 0) {
            _takeCommunity(s.rCommunity, s.tCommunity);
            emit Transfer(sender, communityAddress, s.tCommunity);
        }

        if (s.rBurn > 0 || s.tBurn > 0) {
            _takeBurn(s.rBurn, s.tBurn);
            emit Transfer(sender, deadAddress, s.tBurn);
        }
        emit Transfer(sender, recipient, s.tTransferAmount);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        //calculate how many tokens we need to exchange
        uint256 tokensToSwap = contractTokenBalance / 2;
        uint256 otherHalfOfTokens = tokensToSwap;
        uint256 initialBalance = address(this).balance;
        swapTokensForBNB(tokensToSwap, address(this));
        uint256 newBalance = address(this).balance - (initialBalance);
        addLiquidity(otherHalfOfTokens, newBalance);
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(router), tokenAmount);

        // add the liquidity
        router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function swapTokensForBNB(uint256 tokenAmount, address recipient) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            payable(recipient),
            block.timestamp
        );
    }

    function updateStakingWallet(address newWallet) external onlyOwner {
        require(stakingAddress != newWallet, 'Wallet already set');
        stakingAddress = newWallet;
        _isExcludedFromFee[stakingAddress];
    }

    function updateCommunityWallet(address newWallet) external onlyOwner {
        require(communityAddress != newWallet, 'Wallet already set');
        communityAddress = newWallet;
        _isExcludedFromFee[communityAddress];
    }

    function updateSwapEnabled(bool _enabled) external onlyOwner {
        swapEnabled = _enabled;
    }

    function updateRouterAndPair(address newRouter, address newPair) external onlyOwner {
        router = IRouter(newRouter);
        pair = newPair;
    }

    function taxFreeTransfer(
        address sender,
        address recipient,
        uint256 tAmount
    ) internal {
        uint256 rAmount = tAmount * _getRate();

        if (_isExcluded[sender]) {
            //from excluded
            _tOwned[sender] = _tOwned[sender] - tAmount;
        }
        if (_isExcluded[recipient]) {
            //to excluded
            _tOwned[recipient] = _tOwned[recipient] + tAmount;
        }

        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rAmount;
        emit Transfer(sender, recipient, tAmount);
    }

    //Use this in case BNB are sent to the contract by mistake
    function rescueBNB(uint256 weiAmount) external onlyOwner {
        require(address(this).balance >= weiAmount, 'insufficient BNB balance');
        payable(msg.sender).transfer(weiAmount);
    }

    // Function to allow admin to claim *other* BEP20 tokens sent to this contract (by mistake)
    function rescueAnyBEP20Tokens(
        address _tokenAddr,
        address _to,
        uint256 _amount
    ) public onlyOwner {
        require(_tokenAddr != address(this), 'Cannot transfer out SOM!');
        IERC20(_tokenAddr).transfer(_to, _amount);
    }

    receive() external payable {}

    IAntisnipe public antisnipe = IAntisnipe(address(0));

    bool public antisnipeEnabled = true;

    event AntisnipeDisabled(uint256 timestamp, address user);
    event AntisnipeAddressChanged(address addr);

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        if (from == address(0) || to == address(0)) return;

        if (antisnipeEnabled && address(antisnipe) != address(0)) {
            require(antisnipe.assureCanTransfer(msg.sender, from, to, amount));
        }
    }

    function setAntisnipeDisable() external onlyOwner {
        require(antisnipeEnabled);
        antisnipeEnabled = false;
        emit AntisnipeDisabled(block.timestamp, msg.sender);
    }

    function setAntisnipeAddress(address addr) external onlyOwner {
        antisnipe = IAntisnipe(addr);
        emit AntisnipeAddressChanged(addr);
    }
}