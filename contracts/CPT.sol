//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//the token is used as coupon
contract CPT is ERC20,Ownable,ERC20Burnable{
   constructor(uint256 initialSupply)  ERC20("TCoupon", "CPT") {
        _mint(msg.sender, initialSupply);
    }
    //the consumer who get the CPT token can use it to get a discount
    struct Consumer {
        Product purchasedProdcut; //which product the comsumer purchased
        bool notSpent; //the customer already spent coupon or not
    }

    struct Product {
        string name;
        uint id;
        uint256 price;
        uint256 stock; 
    }

    mapping(address=>Consumer) internal consumers;
    mapping (uint => uint) productIdToArrayIndex;
    Product[] public products;


    function decimals() public view virtual override returns (uint8) {
        return 1;
    }
   
    //consumer get token
    function getCoupon(address receipient) external  returns (bool) {
        //check if the receipient is the owner or not
        require(receipient!=owner(),"don't send coupon to the vendor!");
        //check if address already has token or not
        require(balanceOf(receipient)==0,"You already have the coupon!");
        //check if the balance of owner >=1
        require(balanceOf(owner())>=1,"Not enough coupon!");
       (bool sent) =transfer(receipient,1);
        require(sent, "Failed to buy the coupon");
        return sent;
    }

function useCoupon(string memory productName) external returns(bool){
    //check if productName is not empty
    require(bytes(productName).length != 0);
    //check if there is a product in product list
    Product memory product;
     for (uint i = 0; i <= products.length; i++) {
           if( keccak256(abi.encodePacked((products[i].name))) == keccak256(abi.encodePacked((productName)))){
                product=products[i];
           }
           revert('Not found');
      }
    //check if the stock of product bigger than 1
    require(product.stock>=1,"out of stock");
    //check if the msg.sender has 1 token and not spent yet
    require(balanceOf(msg.sender)==1,"invalid balance!");
    bool spent= consumers[msg.sender].notSpent;
    require(spent,"you have spent your token");
    //add product to consumer
    consumers[msg.sender].purchasedProdcut=product;
    consumers[msg.sender].notSpent=false;
    //burn the token
    _burn(msg.sender, 1);
   return true;
}
    //we need to check if the product is already in the contract before we 
    //put a new product in it. 
    function setProduct(string memory name,uint id,uint256 price,uint256 stock) external onlyOwner {
        uint arrayIndex=productIdToArrayIndex[id];
        require(arrayIndex<1,"This product is already exist!");
      products.push(Product(name,id,price,stock));
        //when the productIdToArrayIndex[id]=1, mean we have already have this produt
        //in product list;
        productIdToArrayIndex[id]=1;
    }
    function getProduct(uint id) public view returns(Product memory){
        Product memory product;
       for (uint i = 0; i <= products.length; i++) {
           if(products[i].id==id){
               product=products[i];
               return product;
           }
      }
      revert('Not found');
    }
    
    function getProducts() public view returns (Product[] memory ){
      Product[] memory Iproducts=new Product[](products.length);
       for (uint i = 0; i < products.length; i++) {
          Product memory Iproduct = products[i];
          Iproducts[i] = Iproduct;
      }
      return Iproducts;
    }
}