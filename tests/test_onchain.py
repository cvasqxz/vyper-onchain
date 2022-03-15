import pytest

@pytest.fixture
def onchain_contract(accounts, Onchain):
    yield Onchain.deploy({'from': accounts[0]})


def test_mint(accounts, onchain_contract):
    max_supply = onchain_contract.maxSupply()
    for i in range(max_supply):
        assert onchain_contract.mint()
        assert onchain_contract.tokenURI(i) == 'miau'
        assert onchain_contract.ownerOf(i) == accounts[0]

