//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract CouponFactory {

    struct Vendor{
        address account;
        //check if the vendor exist, instead of using for loop
        bool _exist;
        //every vendor has its own token/coupon
        ERC20 coupon;
        mapping(uint=>Product) products;
        //for getting off-chain product data
        uint[] productIdList;
        mapping(address=>Consumer) consumers;
        //for getting off-chain consumer data
        address[] consumerIdList;
    }

    struct Consumer {
        Product purchasedProdcut; //which product the comsumer purchased
        bool notSpent; //the customer already spent coupon or not
        address id;
    }

    struct Product {
        string name;
        uint id;
        uint256 price;
        uint256 stock; 
        //check if the product exist, instead of using for loop
        bool _exist;
    }

    //vendor info, token/coupon info and consumer info must be on chain
   mapping(address=>Vendor) vendors;
    
    event couponCreate(string name, string symbol, uint256 totalSupply,address vendor);
    event productSet(Product product,address vendor);
    event consumerGetCoupon(Consumer consumer,address vendor);
    event couponUsed(Consumer consumer,address vendor);
    event productDeleted(uint id, address vendor);

//allow vendor reset the token,but the existing consumer will not able to use the previous token
function resetToken(string memory _name, string memory _symbol, uint256 _tokenSupply) public{
    require(vendors[msg.sender]._exist,"you are not a vendor");
     vendors[msg.sender].coupon= new ERC20(_name, _symbol,msg.sender);
    vendors[msg.sender].coupon._mint(msg.sender, _tokenSupply);
}

    //function that check if the msg.sender is already a vendor
    function isVendor(address _vendor) public view returns (bool){
        return vendors[_vendor]._exist;
    }

    //vendor can create its own token by calling this method
    function createToken(string memory _name, string memory _symbol, uint256 _totalSupply) public  {
        require(vendors[msg.sender]._exist==false,"vendor already exist!");
        vendors[msg.sender].coupon= new ERC20(_name, _symbol,msg.sender);
        vendors[msg.sender].coupon._mint(msg.sender, _totalSupply);
        //vendor can only be on vendors list by creating its own token
         vendors[msg.sender]._exist=true;
         emit couponCreate(_name, _symbol, _totalSupply,msg.sender);
    }
   
    function getBalance(address _vendorAdrs,address owner) public view  returns (uint256)  {
         require(vendors[_vendorAdrs]._exist,"No such vendor");
        return vendors[_vendorAdrs].coupon.balanceOf(owner);
    }
    function getTokenInfo(address _vendorAdrs) public view returns (string memory _name, string memory _symbol, uint256 _totalSupply)  {
         require(vendors[_vendorAdrs]._exist,"No such vendor");
         ERC20 coupon=vendors[_vendorAdrs].coupon;
        return ( coupon.name(), coupon.symbol(), coupon.totalSupply());
    }
    function getTokenOwner(address _vendorAdrs) public view  returns (address){
         require(vendors[_vendorAdrs]._exist,"No such vendor");
        return  vendors[_vendorAdrs].coupon.owner();
    }
    function setProduct(string memory name,uint id,uint256 price,uint256 stock)external{
        //only vendor can set product to its products list
        require(vendors[msg.sender]._exist,"You are not a vendor!");
        require(vendors[msg.sender].products[id]._exist==false,"This product is already exist!");
        vendors[msg.sender].products[id]=Product(name,id,price,stock,true);
        //set product id list for getting off chain products list
         vendors[msg.sender].productIdList.push(id);
         emit productSet(vendors[msg.sender].products[id],msg.sender);
    }

//we may not need to handle the fetch of all products in contract
    //we can store the products data off-chain 
    //fetch those data in the front end by looping the productIdList.
    function getProductIDList(address _vendorAdrs) public view returns(uint[] memory){
        require(vendors[_vendorAdrs]._exist,"No such vendor!");
        uint[] memory productIdList=vendors[_vendorAdrs].productIdList;
        return productIdList;
    }

    function getProducts(address _vendorAdrs) public view returns (Product[] memory products){
        require(vendors[_vendorAdrs]._exist,"No such vendor!");
        uint[] memory productIdList=vendors[_vendorAdrs].productIdList;
       Product[] memory Iproducts= new Product[](productIdList.length); 
       for (uint i = 0; i <productIdList.length; i++) {
          Product memory Iproduct = vendors[_vendorAdrs].products[productIdList[i]];
          Iproducts[i] = Iproduct;
      }
      return Iproducts;
    }

    function getProductInfo(uint id,address _vendorAdrs) public view returns (bool) {
            require(vendors[_vendorAdrs]._exist,"No such vendor!");
            Product memory product= vendors[_vendorAdrs].products[id];
            return product._exist;
    }

    //delete product
    function deleteProduct(uint id,address _vendorAdrs) public returns(bool) {
        require(vendors[_vendorAdrs]._exist,"No such vendor!");
        require(vendors[_vendorAdrs].products[id]._exist,"No such product!");
        vendors[_vendorAdrs].products[id].name="";
        vendors[_vendorAdrs].products[id].id=0;
        vendors[_vendorAdrs].products[id].price=0;
        vendors[_vendorAdrs].products[id].stock=0;
        vendors[_vendorAdrs].products[id]._exist=false;
        emit productDeleted(id, _vendorAdrs);
        return true;
    }

   //consumer get token,one address is allowed to get one token/coupon only
    function getCoupon(address _vendorAdrs, address _consumerAdrs) external  returns (bool) {
         require(_consumerAdrs != address(0), "invalid address");
        //check if the receipient is the owner or not
        require(_consumerAdrs!=_vendorAdrs,"don't send coupon to the vendor!");
        require(vendors[_vendorAdrs]._exist,"No such vendor");
         ERC20 coupon=vendors[_vendorAdrs].coupon;
        //check if consumer already has token or not
        require(coupon.balanceOf(_consumerAdrs)==0,"You already have the coupon!");
        //check if the balance of vendor >=1
        require(coupon.balanceOf( _vendorAdrs)>=1,"Not enough coupon!");
       (bool sent) =coupon.transfer(_consumerAdrs,1);
        require(sent, "Failed to buy the coupon");
        //create a consumer in vendor's consumers list
        Consumer storage consumer =vendors[_vendorAdrs].consumers[_consumerAdrs];
        consumer.notSpent=true;
        consumer.id=_consumerAdrs;
        emit consumerGetCoupon(consumer,_vendorAdrs);
        return sent;
    }

    function useCoupon(address _vendorAdrs,uint productId) external returns(bool){
        require(vendors[_vendorAdrs]._exist,"No such vendor");
    //check if the product exists
    require(vendors[_vendorAdrs].products[productId]._exist,"product not found");
    Product memory product=vendors[_vendorAdrs].products[productId];
    ERC20 coupon=vendors[_vendorAdrs].coupon;
    //check if the stock of product bigger than 1
    require(product.stock>=1,"out of stock");
    //check if the msg.sender has 1 token and not spent yet
    require(coupon.balanceOf(msg.sender)==1,"invalid balance!");
    //vendor should not use coupon
    require(msg.sender!=_vendorAdrs,"vendor should not use coupon!");
    //the msg.sender can only use its own coupon
    Consumer memory consumer=vendors[_vendorAdrs].consumers[msg.sender];
    bool spent= consumer.notSpent;
    require(spent,"you have spent your token");
    product.stock-=1;
    //add product to consumer
    consumer.purchasedProdcut=product;
    consumer.notSpent=false;
    //burn the token
    coupon.burn(msg.sender,1);
    emit couponUsed(consumer,_vendorAdrs);
   return true;
}
}

//this contract is copied from openzeppelin ERC20 contract, but I altered some function to public
//in order to make them available after it is instantialized in other contract
contract ERC20 is Context,IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

  address private _owner;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_,address tokenOwner) {
        _name = name_;
        _symbol = symbol_;
        _owner=tokenOwner;
    }

/**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
       return 1;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        //address owner = _msgSender();
        _transfer(owner(), to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address tokenOwner, address spender) public view virtual override returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        //address owner = _msgSender();
        _approve(owner(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        //address owner = _msgSender();
        _approve(owner(), spender, allowance(owner(), spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        //address owner = _msgSender();
        uint256 currentAllowance = allowance(owner(), spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) public virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }
  function burn(address tokenOwner,uint256 amount) public virtual {
        _burn(tokenOwner, amount);
    }
    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address tokenOwner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(tokenOwner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    /**
     * @dev Updates `tokenOwner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address tokenOwner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(tokenOwner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(tokenOwner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}
