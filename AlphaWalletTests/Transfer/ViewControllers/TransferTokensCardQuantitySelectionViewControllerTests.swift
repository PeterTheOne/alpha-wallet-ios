//Copyright © 2018 Stormbird PTE. LTD.

import FBSnapshotTestCase
@testable import Trust
import UIKit
import TrustKeystore

//TODO re-enable
//class TransferTokensCardQuantitySelectionViewControllerTests: FBSnapshotTestCase {
//    override func setUp() {
//        super.setUp()
//        isDeviceAgnostic = true
//        recordMode = false
//    }
//
//    func testTransferTokensCardQuantitySelectionViewControllerCanBeCreated() {
//        let tokenObject = TokenObject(contract: "0x0000000000000000000000000000000000000001", name: "", symbol: "", decimals: 0, value: "", isCustom: true, isDisabled: false, type: .erc875)
//        let type = PaymentFlow.send(type: .ERC875Token(tokenObject))
//        let token = Token(id: "1", index: 1, name: "", values: ["city": "", "venue": "", "match": 9, "time": GeneralisedTime(string: "20010203160500+0300")!, "numero": 1, "category": "MATCH CLUB", "countryA": "Team A", "countryB": "Team B"])
//        let tokenHolder = TokenHolder(tokens: [token], status: .available, contractAddress: "0x1")
//        let viewModel = TransferTokensCardQuantitySelectionViewModel(token: tokenObject, tokenHolder: tokenHolder)
//        let controller = TransferTokensCardQuantitySelectionViewController(paymentFlow: type, token: tokenObject, viewModel: viewModel)
//        controller.configure()
//
//        FBSnapshotVerifyView(controller.view)
//    }
//}
