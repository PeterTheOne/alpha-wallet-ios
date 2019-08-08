// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol TokenViewControllerDelegate: class, CanOpenURL {
    func didTapSend(forTransferType transferType: TransferType, inViewController viewController: TokenViewController)
    func didTapReceive(forTransferType transferType: TransferType, inViewController viewController: TokenViewController)
    func didTap(transaction: Transaction, inViewController viewController: TokenViewController)
    func didTap(action: TokenInstanceAction, transferType: TransferType, viewController: TokenViewController)
}

class TokenViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    lazy private var header = {
        return TokenViewControllerHeaderView(contract: transferType.contract)
    }()
    lazy private var headerViewModel = SendHeaderViewViewModel(server: session.server)
    private var viewModel: TokenViewControllerViewModel?
    private let session: WalletSession
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let transferType: TransferType
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let buttonsBar = ButtonsBar(numberOfButtons: 2)

    weak var delegate: TokenViewControllerDelegate?

    init(session: WalletSession, tokensDataStore: TokensDataStore, assetDefinition: AssetDefinitionStore, transferType: TransferType) {
        self.session = session
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinition
        self.transferType = transferType

        super.init(nibName: nil, bundle: nil)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        header.delegate = self

        tableView.register(TokenViewControllerTransactionCell.self, forCellReuseIdentifier: TokenViewControllerTransactionCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = header
        tableView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(tableView)

        roundedBackground.addSubview(buttonsBar)

        configureBalanceViewModel()

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),

            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: roundedBackground.bottomAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),
            buttonsBar.bottomAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.marginAtBottomScreen),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: TokenViewControllerViewModel) {
        self.viewModel = viewModel
        view.backgroundColor = viewModel.backgroundColor

        headerViewModel.showAlternativeAmount = viewModel.showAlternativeAmount

        let xmlHandler = XMLHandler(contract: transferType.contract, assetDefinitionStore: assetDefinitionStore)
        if let server = xmlHandler.server, server == session.server {
            let tokenScriptStatusPromise = xmlHandler.tokenScriptStatus
            if tokenScriptStatusPromise.isPending {
                tokenScriptStatusPromise.done { _ in
                    self.configure(viewModel: viewModel)
                }
            }
            header.tokenScriptFileStatus = tokenScriptStatusPromise.value
        } else {
            header.tokenScriptFileStatus = .type0NoTokenScript
        }
        header.sendHeaderView.configure(viewModel: headerViewModel)
        header.frame.size.height = header.systemLayoutSizeFitting(.zero).height + 30

        tableView.tableHeaderView = header

        let actions = viewModel.actions
        buttonsBar.numberOfButtons = actions.count
        buttonsBar.configure()
        for (action, button) in zip(actions, buttonsBar.buttons) {
            button.setTitle(action.name, for: .normal)
            button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
            switch session.account.type {
            case .real:
                button.isEnabled = true
            case .watch:
                button.isEnabled = false
            }
        }

        tableView.reloadData()
    }

    private func configureBalanceViewModel() {
        switch transferType {
        case .nativeCryptocurrency:
            session.balanceViewModel.subscribe { [weak self] viewModel in
                guard let celf = self, let viewModel = viewModel else { return }
                let amount = viewModel.amountShort
                celf.headerViewModel.title = "\(amount) \(celf.session.server.name) (\(viewModel.symbol))"
                let etherToken = TokensDataStore.etherToken(forServer: celf.session.server)
                let ticker = celf.tokensDataStore.coinTicker(for: etherToken)
                celf.headerViewModel.ticker = ticker
                celf.headerViewModel.currencyAmount = celf.session.balanceCoordinator.viewModel.currencyAmount
                celf.headerViewModel.currencyAmountWithoutSymbol = celf.session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
                if let viewModel = celf.viewModel {
                    celf.configure(viewModel: viewModel)
                }
            }
            session.refresh(.ethBalance)
        case .ERC20Token(let token, _, _):
            let viewModel = BalanceTokenViewModel(token: token)
            let amount = viewModel.amountShort
            headerViewModel.title = "\(amount) \(viewModel.name) (\(viewModel.symbol))"
            let etherToken = TokensDataStore.etherToken(forServer: session.server)
            let ticker = tokensDataStore.coinTicker(for: etherToken)
            headerViewModel.ticker = ticker
            headerViewModel.currencyAmount = session.balanceCoordinator.viewModel.currencyAmount
            headerViewModel.currencyAmountWithoutSymbol = session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
            if let viewModel = self.viewModel {
                configure(viewModel: viewModel)
            }
        case .ERC875Token(_), .ERC875TokenOrder(_), .ERC721Token(_), .dapp(_, _):
            break
        }
    }

    @objc private func send() {
        delegate?.didTapSend(forTransferType: transferType, inViewController: self)
    }

    @objc private func receive() {
        delegate?.didTapReceive(forTransferType: transferType, inViewController: self)
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        guard let viewModel = viewModel else { return }
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) {
            if button == sender {
                switch action.type {
                case .erc20Send:
                    send()
                case .erc20Receive:
                    receive()
                case .erc875Redeem, .erc875Sell, .nonFungibleTransfer:
                    break
                case .tokenScript:
                    delegate?.didTap(action: action, transferType: transferType, viewController: self)
                }
                break
            }
        }
    }
}

extension TokenViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TokenViewControllerTransactionCell.identifier, for: indexPath) as! TokenViewControllerTransactionCell
        if let transaction = viewModel?.recentTransactions[indexPath.row] {
            let viewModel = TokenViewControllerTransactionCellViewModel(
                    transaction: transaction,
                    config: session.config,
                    chainState: session.chainState,
                    currentWallet: session.account
            )
            cell.configure(viewModel: viewModel)
        } else {
            cell.configureEmpty()
        }
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.recentTransactions.count ?? 0
    }
}

extension TokenViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let transaction = viewModel?.recentTransactions[indexPath.row] else { return }
        delegate?.didTap(transaction: transaction, inViewController: self)
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 94
    }
}

extension TokenViewController: TokenViewControllerHeaderViewDelegate {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, inHeaderView: TokenViewControllerHeaderView) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: session.server, in: self)
    }

    func didPressViewWebPage(url: URL, inHeaderView: TokenViewControllerHeaderView) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}
