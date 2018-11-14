pragma solidity ^0.4.25;

import './Owned.sol';
import './RealitioSafeMath256.sol';

contract SplitterWallet is Owned {

    // We loop over our recipient list when we need its index, so set a maximum to avoid gas exhaustion
    uint256 constant MAX_RECIPIENTS = 100;

    using RealitioSafeMath256 for uint256;

    mapping(address => uint256) public balanceOf;
    
    // Sum of all balances in balanceOf
    uint256 public balanceTotal; 

    // List of recipients. May contain duplicates to get paid twice.
    address[] public recipients;

    event LogWithdraw(
        address indexed user,
        uint256 amount
    );

    function _recipientIndex(address addr) 
        internal
    view returns (uint256) 
    {
        uint256 i;
        for(i=0; i<recipients.length; i++) {
            if (recipients[i] == addr) {
                return i;
            }
        }
        revert("Recipient not found");
    }

    /// @notice Add a recipient to the list
    /// @param addr The address to add
    function addRecipient(address addr) 
        onlyOwner
    external {
        require(recipients.length < MAX_RECIPIENTS);
        recipients.push(addr);
    }

    /// @notice Remove a recipient from the list
    /// @param old_addr The address to remove
    function removeRecipient(address old_addr) 
        onlyOwner
    external {

        uint256 idx = _recipientIndex(old_addr);
        assert(recipients[idx] == old_addr);

        // If you're not deleting the last item, copy the last item over to the thing you're deleting
        uint256 last_idx = recipients.length - 1;
        if (idx != last_idx) {
            recipients[idx] = recipients[last_idx];
        }

        recipients.length--;
    }

    /// @notice Replace your own address with a different one
    /// @param new_addr The new address
    function replaceSelf(address new_addr) 
    external {
        uint256 idx = _recipientIndex(msg.sender);
        assert(recipients[idx] == msg.sender);
        recipients[idx] = new_addr;
    }

    /// @notice Allocate any unallocated funds from the contract balance
    /// @dev Any time the contract gets funds, they will appear as unallocated
    /// @dev Assign them to the current recipients, and mark them as allocated
    function allocate()
    external {
        uint256 unallocated = address(this).balance.sub(balanceTotal);
        require(unallocated > 0);

        uint256 num_recipients = recipients.length;

        // NB Rounding may leave some funds unallocated, we can claim them later
        uint256 each = unallocated / num_recipients;
        require(each > 0);

        uint256 i;
        for (i=0; i<num_recipients; i++) {
            address recip = recipients[i];
            balanceOf[recip] = balanceOf[recip].add(each);
            balanceTotal = balanceTotal.add(each);
        }

        // If we somehow assigned more money than we have, something is wrong
        assert(address(this).balance >= balanceTotal);

    }

    /// @notice Withdraw the address balance to the owner account
    function withdraw() 
    external {
        uint256 bal = balanceOf[msg.sender];
        require(bal > 0, "Balance must be positive");
        balanceTotal = balanceTotal.sub(bal);
        balanceOf[msg.sender] = 0;
        msg.sender.transfer(bal);
        assert(address(this).balance >= balanceTotal);
        emit LogWithdraw(msg.sender, bal);
    }

    function()
    external payable {
    }

}