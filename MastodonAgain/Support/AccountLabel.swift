//
//  AccountLabel.swift
//  MastodonAgain
//
//  Created by Sam Deane on 22/11/2022.
//

import Mastodon
import SwiftUI

/// Displays an account name, optionally followed by the account handle.
/// The account name is bold, the handle normal.
/// Hovering over the label also shows the handle.

struct AccountLabel: View {
    @EnvironmentObject var appModel: AppModel
    
    let account: Account
    
    init(_ account: Account) {
        self.account = account
    }
    
    var body: some View {
        var text = Text("")
        if !account.displayName.isEmpty {
            // swiftlint:disable shorthand_operator
            text = text + Text("\(account.displayName)")
                .bold()
        }
        
        if appModel.showAccountHandles {
            text = text + Text(" ") + Text("@\(account.acct)")
                .foregroundColor(.secondary)
        }
        
        return text
            .help(account.acct) // TODO: only if handles are normally hidden?
    }
}
