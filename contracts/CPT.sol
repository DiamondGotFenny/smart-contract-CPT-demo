//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//the token is used as coupon
contract CPT is ERC20,Ownable,ERC20Burnable{
   constructor(uint256 initialSupply)  ERC20("TCoupon", "CPT") {
        require(initialSupply>=0,"supply token number must bigger than 0!");
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
        bool _exist;
    }

    mapping(address=>Consumer) consumers;
    mapping(uint=>Product) product;
    uint[] productIdList;
    
    event consumerGetCoupon(address indexed receipient,uint tokenAmount,uint256 timeStamp);

    function decimals() public view virtual override returns (uint8) {
        return 1;
    }
   
    //consumer get token,one address is allowed to get one token/coupon only
    function getCoupon(address receipient) external  returns (bool) {
         require(receipient != address(0), "invalid address");
        //check if the receipient is the owner or not
        require(receipient!=owner(),"don't send coupon to the vendor!");
        //check if address already has token or not
        require(balanceOf(receipient)==0,"You already have the coupon!");
        //check if the balance of owner >=1
        require(balanceOf(owner())>=1,"Not enough coupon!");
       (bool sent) =transfer(receipient,1);
        require(sent, "Failed to buy the coupon");
        consumers[receipient].notSpent=true;
        emit consumerGetCoupon(receipient,1,block.timestamp);
        return sent;
    }

function useCoupon(uint productId) external returns(bool){
    //check if the product exists
    require(product[productId]._exist,"product not found");
    //check if the stock of product bigger than 1
    require(product[productId].stock>=1,"out of stock");
    //check if the msg.sender has 1 token and not spent yet
    require(balanceOf(msg.sender)==1,"invalid balance!");
    //owner should not use coupon
    require(msg.sender!=owner(),"vendor should not use coupon!");
    bool spent= consumers[msg.sender].notSpent;
    require(spent,"you have spent your token");
    product[productId].stock-=1;
    //add product to consumer
    consumers[msg.sender].purchasedProdcut=product[productId];
    consumers[msg.sender].notSpent=false;
    //burn the token
    burn(1);
   return true;
}
    //we need to check if the product is already in the contract before we 
    //put a new product in it. 
    function setProduct(string memory name,uint id,uint256 price,uint256 stock) external onlyOwner {
      require(product[id]._exist==false,"This product is already exist!");
      product[id]=Product(name,id,price,stock,true);
      productIdList.push(id);
    }

    function getProduct(uint id) public view returns(Product memory){
        if(product[id]._exist){
            return product[id];
        }
      revert('Not found');
    }
    
    //we may not need to handle the fetch of all products in contract
    //we can do it in the front end by looping the productIdList.
    function getProductIDList() public view returns(uint[] memory){
        return productIdList;
    }
    function getProducts() public view returns (Product[] memory ){
      Product[] memory Iproducts=new Product[](productIdList.length);
       for (uint i = 0; i < productIdList.length; i++) {
          Product memory Iproduct = product[productIdList[i]];
          Iproducts[i] = Iproduct;
      }
      return Iproducts;
    }
    function getConsumerInfo(address consumerAdrs) public view returns(Consumer memory){
         require(consumerAdrs != address(0), "invalid address");
        return consumers[consumerAdrs];
    }
}
