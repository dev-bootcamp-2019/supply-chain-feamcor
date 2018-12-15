pragma solidity ^0.4.13;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/SupplyChain.sol";

contract SupplyChainProxy {
    SupplyChain public supplyChain;

    constructor(address _supplyChainAddress) public {
        supplyChain = SupplyChain(_supplyChainAddress);
    }

    function addItem(string _name, uint _price) public {
        supplyChain.addItem(_name, _price);
    }

    function buyItem(uint _sku, uint _price) public payable returns(bool) {
        return address(supplyChain).call.value(_price)(abi.encodeWithSignature("buyItem(uint256)"), _sku);
    }

    function shipItem(uint _sku) public {
        supplyChain.shipItem(_sku);
    }

    function receiveItem(uint _sku) public {
        supplyChain.receiveItem(_sku);
    }

    function() public payable {}
}

contract TestSupplyChain {
    uint public initialBalance = 5 ether;

    function testConstructor() public {
        SupplyChain supplyChain = new SupplyChain();
        Assert.equal(supplyChain.owner(), this, "owner is incorrect");
        Assert.equal(supplyChain.skuCount(), 0, "skuCount is not zero");
    }

    function testAddItem() public {
        SupplyChain supplyChain = new SupplyChain();
        SupplyChainProxy sellerProxy = new SupplyChainProxy(address(supplyChain));
        sellerProxy.addItem("item 1", 0.01 ether);
        Assert.equal(supplyChain.skuCount(), 1, "sku count not updated");
        (string memory _name, uint _sku, uint _price, uint _state, address _seller, address _buyer) = supplyChain.fetchItem(0);
        Assert.equal(_name, "item 1", "invalid item name");
        Assert.equal(_sku, 0, "invalid item sku");
        Assert.equal(_price, 0.01 ether, "invalid item price");
        Assert.equal(_state, uint(SupplyChain.State.ForSale), "item not for sale");
        Assert.equal(_seller, address(sellerProxy), "invalid seller");
        Assert.equal(_buyer, 0x0, "invalid buyer");
    }

    function testBuyItem() public {
        SupplyChain supplyChain = new SupplyChain();
        SupplyChainProxy sellerProxy = new SupplyChainProxy(address(supplyChain));
        sellerProxy.addItem("item 1", 0.01 ether);
        SupplyChainProxy buyerProxy = new SupplyChainProxy(address(supplyChain));
        Assert.equal(address(buyerProxy).balance, 0 ether, "buyer's balance is not zero");
        address(buyerProxy).transfer(1 ether);
        Assert.equal(address(buyerProxy).balance, 1 ether, "buyer's balance is not one ether");
        (,,, uint _state1,,) = supplyChain.fetchItem(0);
        Assert.equal(_state1, uint(SupplyChain.State.ForSale), "item not for sale");
        buyerProxy.buyItem(0, 0.01 ether);
        Assert.equal(address(buyerProxy).balance, 1 ether - 0.01 ether, "buyer's balance was not debited");
        (,,, uint _state2,, address _buyer) = supplyChain.fetchItem(0);
        Assert.equal(_state2, uint(SupplyChain.State.Sold), "item not sold");
        Assert.equal(_buyer, address(buyerProxy), "invalid buyer");
    }

    function testShipItem() public {
        SupplyChain supplyChain = new SupplyChain();
        SupplyChainProxy sellerProxy = new SupplyChainProxy(address(supplyChain));
        sellerProxy.addItem("item 1", 0.01 ether);
        SupplyChainProxy buyerProxy = new SupplyChainProxy(address(supplyChain));
        address(buyerProxy).transfer(1 ether);
        buyerProxy.buyItem(0, 0.01 ether);
        (,,, uint _state1,,) = supplyChain.fetchItem(0);
        Assert.equal(_state1, uint(SupplyChain.State.Sold), "item not sold");
        sellerProxy.shipItem(0);
        (,,, uint _state2,,) = supplyChain.fetchItem(0);
        Assert.equal(_state2, uint(SupplyChain.State.Shipped), "item not shipped");
    }

    function testReceiveItem() public {
        SupplyChain supplyChain = new SupplyChain();
        SupplyChainProxy sellerProxy = new SupplyChainProxy(address(supplyChain));
        sellerProxy.addItem("item 1", 0.01 ether);
        SupplyChainProxy buyerProxy = new SupplyChainProxy(address(supplyChain));
        address(buyerProxy).transfer(1 ether);
        buyerProxy.buyItem(0, 0.01 ether);
        sellerProxy.shipItem(0);
        (,,, uint _state1,,) = supplyChain.fetchItem(0);
        Assert.equal(_state1, uint(SupplyChain.State.Shipped), "item not shipped");
        buyerProxy.receiveItem(0);
        (,,, uint _state2,,) = supplyChain.fetchItem(0);
        Assert.equal(_state2, uint(SupplyChain.State.Received), "item not received");
    }

    function() public payable {}
}
