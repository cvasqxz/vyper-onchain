# @version ^0.2.0
from vyper.interfaces import ERC721

implements: ERC721

interface ERC721Receiver:
    def onERC721Received(
        _operator: address,
        _from: address,
        _tokenId: uint256,
        _data: Bytes[1024]
        ) -> bytes32: view

event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    tokenId: indexed(uint256)

event Approval:
    owner: indexed(address)
    approved: indexed(address)
    tokenId: indexed(uint256)

event ApprovalForAll:
    owner: indexed(address)
    operator: indexed(address)
    approved: bool

event OwnershipTransferred:
    previousOwner: indexed(address)
    newOwner: indexed(address)


idToOwner: HashMap[uint256, address]
idToApprovals: HashMap[uint256, address]
ownerToNFTokenCount: HashMap[address, uint256]
ownerToOperators: HashMap[address, HashMap[address, bool]]
supportedInterfaces: HashMap[bytes32, bool]

name: public(String[13])
symbol: public(String[8])
maxSupply: public(uint256)
contractStatus: public(bool)

mintPrice: uint256
tokenIndex: uint256

ownerAddress: address

ERC165_INTERFACE_ID: constant(bytes32) = 0x0000000000000000000000000000000000000000000000000000000001ffc9a7
ERC721_INTERFACE_ID: constant(bytes32) = 0x0000000000000000000000000000000000000000000000000000000080ac58cd


@external
def __init__():
    self.supportedInterfaces[ERC165_INTERFACE_ID] = True
    self.supportedInterfaces[ERC721_INTERFACE_ID] = True
    self.name = "NüCLK Péndulo"
    self.symbol = "NUCLK002"

    # 200 NFTs @ 0.05 ETH
    self.maxSupply = 200
    self.mintPrice = 50000000000000000

    self.ownerAddress = msg.sender
    self.contractStatus = False


# OWNABLE & PAUSABLE

@internal
def _onlyOwner(_owner: address) -> bool:
    return _owner == self.ownerAddress


@internal
def _transferOwnership(_newOwner: address):
    oldOwner: address = self.ownerAddress
    self.ownerAddress = _newOwner
    log OwnershipTransferred(oldOwner, _newOwner)


@view
@external
def owner() -> address:
    return self.ownerAddress
    

@external
def transferOwnership(_newOwner: address):
    assert self._onlyOwner(msg.sender)
    self._transferOwnership(_newOwner)


@external
def renounceOwnership():
    assert self._onlyOwner(msg.sender)
    self._transferOwnership(ZERO_ADDRESS)
    

@external
def pause():
    assert self._onlyOwner(msg.sender)
    self.contractStatus = not self.contractStatus


@external
def widthraw():
    assert self._onlyOwner(msg.sender)
    send(self.ownerAddress, self.balance)


# ERC721 STANDARD

@view
@external
def supportsInterface(_interfaceID: bytes32) -> bool:
    return self.supportedInterfaces[_interfaceID]


@view
@external
def balanceOf(_owner: address) -> uint256:
    assert _owner != ZERO_ADDRESS
    return self.ownerToNFTokenCount[_owner]


@view
@external
def ownerOf(_tokenId: uint256) -> address:
    owner: address = self.idToOwner[_tokenId]
    assert owner != ZERO_ADDRESS
    return owner


@view
@external
def getApproved(_tokenId: uint256) -> address:
    assert self.idToOwner[_tokenId] != ZERO_ADDRESS
    return self.idToApprovals[_tokenId]


@view
@external
def isApprovedForAll(_owner: address, _operator: address) -> bool:
    return (self.ownerToOperators[_owner])[_operator]


@view
@internal
def _isApprovedOrOwner(_spender: address, _tokenId: uint256) -> bool:
    owner: address = self.idToOwner[_tokenId]
    spender_onlyOwner: bool = owner == _spender
    spenderIsApproved: bool = _spender == self.idToApprovals[_tokenId]
    spenderIsApprovedForAll: bool = (self.ownerToOperators[owner])[_spender]
    return (spender_onlyOwner or spenderIsApproved) or spenderIsApprovedForAll


@internal
def _addTokenTo(_to: address, _tokenId: uint256):
    assert self.idToOwner[_tokenId] == ZERO_ADDRESS
    self.idToOwner[_tokenId] = _to
    self.ownerToNFTokenCount[_to] += 1


@internal
def _removeTokenFrom(_from: address, _tokenId: uint256):
    assert self.idToOwner[_tokenId] == _from
    self.idToOwner[_tokenId] = ZERO_ADDRESS
    self.ownerToNFTokenCount[_from] -= 1


@internal
def _clearApproval(_owner: address, _tokenId: uint256):
    assert self.idToOwner[_tokenId] == _owner
    if self.idToApprovals[_tokenId] != ZERO_ADDRESS:
        self.idToApprovals[_tokenId] = ZERO_ADDRESS


@internal
def _transferFrom(_from: address, _to: address, _tokenId: uint256, _sender: address):
    assert self._isApprovedOrOwner(_sender, _tokenId)
    assert _to != ZERO_ADDRESS
    self._clearApproval(_from, _tokenId)
    self._removeTokenFrom(_from, _tokenId)
    self._addTokenTo(_to, _tokenId)
    log Transfer(_from, _to, _tokenId)


@external
def transferFrom(_from: address, _to: address, _tokenId: uint256):
    self._transferFrom(_from, _to, _tokenId, msg.sender)


@external
def safeTransferFrom(_from: address, _to: address, _tokenId: uint256, _data: Bytes[1024]=b""):
    self._transferFrom(_from, _to, _tokenId, msg.sender)

    if _to.is_contract:
        returnValue: bytes32 = ERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data)
        assert returnValue == method_id("onERC721Received(address,address,uint256,bytes)", output_type=bytes32)


@external
def approve(_approved: address, _tokenId: uint256):
    owner: address = self.idToOwner[_tokenId]
    assert owner != ZERO_ADDRESS
    assert _approved != owner
    
    sender_onlyOwner: bool = self.idToOwner[_tokenId] == msg.sender
    senderIsApprovedForAll: bool = (self.ownerToOperators[owner])[msg.sender]
    assert (sender_onlyOwner or senderIsApprovedForAll)
    
    self.idToApprovals[_tokenId] = _approved
    log Approval(owner, _approved, _tokenId)


@external
def setApprovalForAll(_operator: address, _approved: bool):
    assert _operator != msg.sender
    self.ownerToOperators[msg.sender][_operator] = _approved
    log ApprovalForAll(msg.sender, _operator, _approved)


# Modified Functions

@payable
@external
@nonreentrant("lock")
def mint() -> bool:
    assert self.tokenIndex < self.maxSupply
    assert msg.value >= self.mintPrice
    
    self._addTokenTo(msg.sender, self.tokenIndex)
    log Transfer(ZERO_ADDRESS, msg.sender, self.tokenIndex)
    self.tokenIndex += 1
    return True


@view
@external
def tokenURI(_tokenId: uint256) -> String[1024]:
    assert _tokenId < self.tokenIndex
    baseJSON: String[1024] = '{"hola":"chao"}'
    return baseJSON
    