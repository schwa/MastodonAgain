import Mastodon
import SwiftUI

extension Card {
    var size: CGSize? {
        guard let width, let height, width > 0, height > 0 else {
            appLogger?.warning("Zero width/height card")
            return nil
        }
        return CGSize(width: width, height: height)
    }
}

struct CardView: View {
    let card: Card

    var body: some View {
        switch card.type {
        case .link:
            Link(destination: card.url) {
                HStack {
                    if let image = card.image {
                        ContentImage(url: image, size: card.size, blurhash: card.blurhash)
                            .frame(maxHeight: 80)
                            .border(Color.purple)
                    }
                    if let description = card.title ?? card.description {
                        Label("\(description) (\(card.url.absoluteString))", systemImage: "link").symbolVariant(.circle)
                    }
                    else {
                        Label(card.url.absoluteString, systemImage: "link").symbolVariant(.circle)
                    }
                }
            }
//            if let width = card.width, let height = card.height, let blurHash = card.blurhash {
//                Image(blurHash: blurHash, size: [width, height])
//            }
// {"url":"https://twitodon.com/","title":"Twitodon - Find your Twitter friends on Mastodon","description":"","type":"link","author_name":"","author_url":"","provider_name":"","provider_url":"","html":"","width":0,"height":0,"image":null,"embed_url":"","blurhash":null}

//            "card" : {
//                "author_name" : "",
//                "author_url" : "",
//                "blurhash" : "U009m+ayWBaxROj[ofj]ozayayayayj[f6j[",
//                "description" : "“Riven.\n\nOfficially in development at Cyan.\n\nFAQ: https://t.co/6YeeamoJaq”",
//                "embed_url" : "",
//                "height" : 225,
//                "html" : "",
//                "image" : "https://files.mastodon.social/cache/preview_cards/images/046/839/502/original/d99d01f5953824cf.jpeg",
//                "provider_name" : "Twitter",
//                "provider_url" : "",
//                "title" : "Cyan Inc. on Twitter",
//                "type" : "link",
//                "url" : "https://twitter.com/cyanworlds/status/1587065601339424770",
//                "width" : 400
//            },

        case .photo:
            Text("Photo Card: \(String(describing: card))").debuggingInfo()
        case .video:
            Text("Video Card: \(String(describing: card))").debuggingInfo()
        case .rich:
            Text("Video Card: \(String(describing: card))").debuggingInfo()
        }
    }
}
