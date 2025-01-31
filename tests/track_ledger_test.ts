import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create new item and verify its details",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const metadata = "Test Item #1";
    
    let block = chain.mineBlock([
      Tx.contractCall('track-ledger', 'create-item', [
        types.utf8(metadata)
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk().expectUint(1);
    
    // Verify item details
    let verifyBlock = chain.mineBlock([
      Tx.contractCall('track-ledger', 'get-item', [
        types.uint(1)
      ], deployer.address)
    ]);
    
    const itemData = verifyBlock.receipts[0].result.expectSome();
    assertEquals(itemData.owner, deployer.address);
    assertEquals(itemData.metadata, metadata);
    assertEquals(itemData.status, types.uint(1));
  }
});

Clarinet.test({
  name: "Can create and manage item batches",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    // Create multiple items
    let block = chain.mineBlock([
      Tx.contractCall('track-ledger', 'create-item', [
        types.utf8("Item 1")
      ], deployer.address),
      Tx.contractCall('track-ledger', 'create-item', [
        types.utf8("Item 2")
      ], deployer.address)
    ]);
    
    // Create batch with items
    let batchBlock = chain.mineBlock([
      Tx.contractCall('track-ledger', 'create-batch', [
        types.list([types.uint(1), types.uint(2)])
      ], deployer.address)
    ]);
    
    batchBlock.receipts[0].result.expectOk().expectUint(1);
    
    // Verify batch details
    let verifyBlock = chain.mineBlock([
      Tx.contractCall('track-ledger', 'get-batch', [
        types.uint(1)
      ], deployer.address)
    ]);
    
    const batchData = verifyBlock.receipts[0].result.expectSome();
    assertEquals(batchData.owner, deployer.address);
    assertEquals(batchData.items.length, 2);
  }
});

Clarinet.test({
  name: "Can transfer ownership of item",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // First create an item
    let block = chain.mineBlock([
      Tx.contractCall('track-ledger', 'create-item', [
        types.utf8("Test Item")
      ], deployer.address)
    ]);
    
    // Then transfer ownership
    let transferBlock = chain.mineBlock([
      Tx.contractCall('track-ledger', 'transfer-ownership', [
        types.uint(1),
        types.principal(wallet1.address)
      ], deployer.address)
    ]);
    
    transferBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Verify new owner
    let verifyBlock = chain.mineBlock([
      Tx.contractCall('track-ledger', 'get-item', [
        types.uint(1)
      ], deployer.address)
    ]);
    
    const itemData = verifyBlock.receipts[0].result.expectSome();
    assertEquals(itemData.owner, wallet1.address);
  }
});

Clarinet.test({
  name: "Can update item status",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    // Create item
    let block = chain.mineBlock([
      Tx.contractCall('track-ledger', 'create-item', [
        types.utf8("Test Item")
      ], deployer.address)
    ]);
    
    // Update status to in-transit
    let updateBlock = chain.mineBlock([
      Tx.contractCall('track-ledger', 'update-status', [
        types.uint(1),
        types.uint(2) // STATUS-IN-TRANSIT
      ], deployer.address)
    ]);
    
    updateBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Verify status
    let verifyBlock = chain.mineBlock([
      Tx.contractCall('track-ledger', 'get-item', [
        types.uint(1)
      ], deployer.address)
    ]);
    
    const itemData = verifyBlock.receipts[0].result.expectSome();
    assertEquals(itemData.status, types.uint(2));
  }
});
