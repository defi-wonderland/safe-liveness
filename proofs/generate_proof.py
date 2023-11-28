import argparse
import json
import rlp

from proof_utils import request_block_header, request_account_proof, mine_anvil_block

def main():
  # Parse command line arguments
  parser = argparse.ArgumentParser(
        description="Patricia Merkle Trie Proof Generating Tool",
        formatter_class=argparse.RawTextHelpFormatter)
  
  parser.add_argument("-r", "--rpc",
        default="http://localhost:8545",
        type=str,
        help="URL of a full node RPC endpoint, e.g. http://localhost:8545")
  
  parser.add_argument("--contract",
        type=str,
        help="Storage mirror contract address")
  
  parser.add_argument("--slot",
        type=str,
        help="Storage slot to generate proof for")

  # Save command line arguments into variables
  args = parser.parse_args()
  
  mine_anvil_block(args.rpc)
  
  rpc_endpoint = args.rpc
  block_number = "latest"
  storage_mirror_contract_address = args.contract
  storage_slot = args.slot
  clean_storage_slot = bytes.fromhex(storage_slot[2:])
 
  mine_anvil_block(rpc_endpoint)
  # Generate proof data
  (block_number, block_header, acct_proof, storage_proofs) = generate_proof_data(rpc_endpoint, block_number, storage_mirror_contract_address, [clean_storage_slot])
  
  # Encode the proof data
  account_proof = rlp.encode(acct_proof)
  storage_proof = rlp.encode(storage_proofs[0])
  encoded_block_header = rlp.encode(block_header)

  # Output the proof data in JSON format
  output = {
    "blockNumber": block_number,
    "blockHeader": encoded_block_header.hex(),
    "accountProof": account_proof.hex(),
    "storageProof": storage_proof.hex()
  }

  # Serializing json
  json_object = json.dumps(output, indent=4)  

  with open("./proofs/proof.json", "w") as outfile:
    outfile.write(json_object)

def generate_proof_data(
    rpc_endpoint,
    block_number,
    address,
    slots
):
    block_number = \
        block_number if block_number == "latest" or block_number == "earliest" \
        else hex(int(block_number))

    # Block header is currently not being calculated correctly
    (block_number, block_header) = request_block_header(
        rpc_endpoint=rpc_endpoint,
        block_number=block_number,
    )

    (acct_proof, storage_proofs) = request_account_proof(
        rpc_endpoint=rpc_endpoint,
        block_number=block_number,
        address=address,
        slots=slots,
    )

    return (
        block_number,
        block_header,
        acct_proof,
        storage_proofs
    )

if __name__ == "__main__":
    main()
    exit(0)
