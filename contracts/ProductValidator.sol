
pragma solidity >=0.4.21 <0.6.0;
pragma experimental ABIEncoderV2;

contract ProductValidator {

    enum EntityType{ OEM, ProductOwner, Distributor, Retailer, Customer }
    //
    // Entity holds the physical validation of the owner
    // name: Name of the owner as per the ID provided.
    // ID: Identifier for the owner
    // IDType: Provider who can validate the ID provided.
    //
    struct Entity {
        EntityType entityType;
        string name;
        string IDEntity;
        string IDType;
        address owner;
        uint index;
    }

    Entity[] public entities;

    // Entity ID to Entity mapping...
    mapping(string=>Entity) private entityMap;

    // Entity address to entity map
    mapping(address=>Entity) private addressEntityMap;

    //
    // Product holds the information about the product.
    // ID: RFID or BarCode tag for the product.
    // origniHash: The origin hash to track the product origin and other attributes.
    //

    struct Product {
        string IDProduct;
        bytes32 originHash;
        address OEM;
    }
    Product[] private bags;
    // Product ID to Product mapping...
    mapping (string=>Product) bagMapping;

    // Product ID to owning entity mapping...
    mapping (string=>Entity) productEntityMap;

    address private productOwner;
    Entity private productOwnerEntity;

    mapping(address=>Entity) OEMMapping;
    address[] private OEMList;

    function createEntity(string memory _name, string memory _ID, string memory _IDType) public {
        Entity memory entity;
        entity.IDEntity = _ID;
        entity.name = _name;
        entity.IDType = _IDType;
        entity.entityType = EntityType.Customer;
        entity.owner = msg.sender;
        entity.index = entities.length;
        entities.push(entity);
        entityMap[_ID] = entity;
        addressEntityMap[entity.owner] = entity;
    }

    // Owner of the product creates should create the contract.
    constructor (string memory _productOwnerName) public {
        productOwner = msg.sender;
        Entity memory entity;
        entity.IDEntity = "1";
        entity.name = _productOwnerName;
        entity.IDType = "";
        entity.entityType = EntityType.ProductOwner;
        entity.owner = msg.sender;
        entity.index = entities.length;
        entities.push(entity);
        entityMap[entity.IDEntity] = entity;
        addressEntityMap[entity.owner] = entity;
        productOwnerEntity = entities[0];
    }

    function authorizeOEM(address _oem, string memory _oemEntityID) public {
        require(msg.sender == productOwner, "Only prodcut owner can authorize OEM.");
        Entity storage entity = entityMap[_oemEntityID];
        entity.entityType = EntityType.OEM;
        entities[entity.index] = entity;
        OEMMapping[_oem] = entityMap[_oemEntityID];
        addressEntityMap[entity.owner] = entity;
    }

    function authorizeDistributor(string memory _distID) public {
        require(msg.sender == productOwner, "Only prodcut owner can authorize Distributor.");
        entityMap[_distID].entityType = EntityType.Distributor;
        addressEntityMap[entityMap[_distID].owner] = entityMap[_distID];
    }

    function authorizeRetailer(string memory _retailID) public {
        require(addressEntityMap[msg.sender].entityType == EntityType.Distributor,
            "Only distributor can authorize retailer.");
        entityMap[_retailID].entityType = EntityType.Retailer;
        addressEntityMap[entityMap[_retailID].owner] = entityMap[_retailID];
    }

    function createTag(string memory _IDProduct, bytes32 _originHash) public
    {
        require(OEMMapping[msg.sender].entityType == EntityType.OEM, "Only OEM can create tags.");
        Product memory bag;
        bag.IDProduct = _IDProduct;
        bag.originHash = _originHash;
        bag.OEM = msg.sender;
        bags.push(bag);
        bagMapping[bag.IDProduct] = bag;
        productEntityMap[bag.IDProduct] = productOwnerEntity;
    }

    function getOwnershipInfo(string memory _IDProduct) public view returns (Entity memory) {
        return productEntityMap[_IDProduct];
    }

    function getEntity(string memory _IDEntity) public view returns (Entity memory) {
        return entityMap[_IDEntity];
    }

    function getEntityByAddress(address _add) public view returns (Entity memory) {
        return addressEntityMap[_add];
    }

    function transferOwnership(string memory _IDProduct, string memory _IDNewEntity, address _newOwner) public {
        require(productEntityMap[_IDProduct].owner == msg.sender && (
            // Product Owner can transfer to distributor.

        (productEntityMap[_IDProduct].entityType == EntityType.ProductOwner && entityMap[_IDNewEntity].entityType == EntityType.Distributor) ||
        (productEntityMap[_IDProduct].entityType == EntityType.Distributor && entityMap[_IDNewEntity].entityType == EntityType.Retailer) ||
        (productEntityMap[_IDProduct].entityType == EntityType.Retailer && entityMap[_IDNewEntity].entityType == EntityType.Customer)),
        "Doesn't meet the ownership transfer rules.");

        productEntityMap[_IDProduct].owner = _newOwner;
        addressEntityMap[_newOwner] = entityMap[_IDNewEntity];
        productEntityMap[_IDProduct] = entityMap[_IDNewEntity];
    }
}