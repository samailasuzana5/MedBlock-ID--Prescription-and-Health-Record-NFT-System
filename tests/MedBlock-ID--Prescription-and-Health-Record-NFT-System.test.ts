import { Clarinet, Tx, Chain, Account, types } from '@stacks/transactions';

Clarinet.test({
  name: "Ensure that doctor registration works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const doctor = accounts.get("wallet_1")!;

    let block = chain.mineBlock([
      Tx.contractCall(
        "MedBlock-ID--Prescription-and-Health-Record-NFT-System",
        "register-doctor",
        [types.principal(doctor.address), types.ascii("General Hospital")],
        deployer.address
      )
    ]);
    block.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Ensure that patient registration works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const patient = accounts.get("wallet_2")!;

    let block = chain.mineBlock([
      Tx.contractCall(
        "MedBlock-ID--Prescription-and-Health-Record-NFT-System",
        "register-patient",
        [types.ascii("John Doe"), types.uint(19900101)],
        patient.address
      )
    ]);
    block.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Ensure medical record creation works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const doctor = accounts.get("wallet_1")!;
    const patient = accounts.get("wallet_2")!;

    // Setup
    chain.mineBlock([
      Tx.contractCall(
        "MedBlock-ID--Prescription-and-Health-Record-NFT-System",
        "register-doctor",
        [types.principal(doctor.address), types.ascii("General Hospital")],
        deployer.address
      ),
      Tx.contractCall(
        "MedBlock-ID--Prescription-and-Health-Record-NFT-System",
        "register-patient",
        [types.ascii("John Doe"), types.uint(19900101)],
        patient.address
      )
    ]);

    // Create record
    let block = chain.mineBlock([
      Tx.contractCall(
        "MedBlock-ID--Prescription-and-Health-Record-NFT-System",
        "create-medical-record",
        [
          types.principal(patient.address),
          types.ascii("Common Cold"),
          types.ascii("Acetaminophen 500mg")
        ],
        doctor.address
      )
    ]);
    block.receipts[0].result.expectOk();
  },
});
