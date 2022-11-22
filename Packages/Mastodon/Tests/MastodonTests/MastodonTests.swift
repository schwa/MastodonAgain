@testable import Mastodon
import XCTest
import SwiftSoup

final class HTMLTests: XCTestCase {
    func test1() throws {
        let html = HTML("<p>A simple link <a href=\"http://apple.com/\" target=\"_blank\" rel=\"nofollow noopener noreferrer\"><span class=\"invisible\">http://</span><span class=\"\">apple.com/</span><span class=\"invisible\"></span></a></p>")
        let safe = try html.safeHTML
        let expected = HTML(#"<p>A simple link <a href="http://apple.com/" rel="nofollow"><span class="invisible">http://</span><span class="">apple.com/</span><span class="invisible"></span></a></p>"#)
        XCTAssertEqual(safe, expected)
    }

    func test2() throws {
        let html = HTML("<p>A <a href=\"https://fosstodon.org/tags/hashtag\" class=\"mention hashtag\" rel=\"tag\">#<span>hashtag</span></a>, a username @schwa, a link <a href=\"http://apple.com/\" target=\"_blank\" rel=\"nofollow noopener noreferrer\"><span class=\"invisible\">http://</span><span class=\"\">apple.com/</span><span class=\"invisible\"></span></a></p>")
        let safe = try html.safeHTML
        let expected = HTML(#"<p>A <a href="https://fosstodon.org/tags/hashtag" class="mention hashtag" rel="nofollow">#<span>hashtag</span></a>, a username @schwa, a link <a href="http://apple.com/" rel="nofollow"><span class="invisible">http://</span><span class="">apple.com/</span><span class="invisible"></span></a></p>"#)
        XCTAssertEqual(safe, expected)
    }

    func test3() throws {
        let html = HTML("<p>A working username <span class=\"h-card\"><a href=\"https://fosstodon.org/@schwadev\" class=\"u-url mention\">@<span>schwadev</span></a></span></p>")
        let safe = try html.safeHTML
        let expected = HTML(#"<p>A working username <span class="h-card"><a href="https://fosstodon.org/@schwadev" class="u-url mention" rel="nofollow">@<span>schwadev</span></a></span></p>"#)
        XCTAssertEqual(safe, expected)
    }

    func test4() throws {
        let html = HTML("<p>A link: <a href=\"http://apple.com/\" target=\"_blank\" rel=\"nofollow noopener noreferrer\"><span class=\"invisible\">http://</span><span class=\"\">apple.com/</span><span class=\"invisible\"></span></a><br />A hashtag: <a href=\"https://fosstodon.org/tags/cheese\" class=\"mention hashtag\" rel=\"tag\">#<span>cheese</span></a><br />A user: <span class=\"h-card\"><a href=\"https://fosstodon.org/@schwadev\" class=\"u-url mention\">@<span>schwadev</span></a></span><br />A remote user <span class=\"h-card\"><a href=\"https://mastodon.social/@schwa\" class=\"u-url mention\">@<span>schwa</span></a></span></p>")

        let expected = HTML(#"""
<html>
 <head></head>
 <body>
  <p>A link: <a href="http://apple.com/" rel="nofollow" class="link">http://apple.com/</a><br>A hashtag: <a href="https://fosstodon.org/tags/cheese" class="hashtag">#cheese</a><br>A user: <a class="user" href="https://fosstodon.org/@schwadev">@schwadev</a><br>A remote user <a class="user" href="https://mastodon.social/@schwa">@schwa</a></p>
 </body>
</html>
"""#)
        let result = try html.rewrittenMastodonHTML
        XCTAssertEqual(result, expected)
    }

    func test5() throws {
        let html = HTML("<p>A link: <a href=\"http://apple.com/\" target=\"_blank\" rel=\"nofollow noopener noreferrer\"><span class=\"invisible\">http://</span><span class=\"\">apple.com/</span><span class=\"invisible\"></span></a><br />A hashtag: <a href=\"https://fosstodon.org/tags/cheese\" class=\"mention hashtag\" rel=\"tag\">#<span>cheese</span></a><br />A user: <span class=\"h-card\"><a href=\"https://fosstodon.org/@schwadev\" class=\"u-url mention\">@<span>schwadev</span></a></span><br />A remote user <span class=\"h-card\"><a href=\"https://mastodon.social/@schwa\" class=\"u-url mention\">@<span>schwa</span></a></span></p>")

        let result = try html.mastodonAttributedString
//        print("###############################################")
//        print(html.rawValue.replacing("<br />", with: "<br>\n"))
        print(result)
    }

    func test6() throws {
        let html = HTML("<p>From July 2011,</p><p><span class=\"h-card\"><a href=\"https://mastodon.cloud/@anildash\" class=\"u-url mention\" rel=\"nofollow noopener noreferrer\" target=\"_blank\">@<span>anildash</span></a></span>'s wise counsel :</p><p>\"You should make a budget that supports having a good community,</p><p>... Every single person who’s going to object to these ideas is going to talk about how they can’t afford to hire a community manager,</p><p>Or how it’s so expensive to develop good tools for managing comments.</p><p>Okay,</p><p>Then save money by turning off your web server.</p><p>Or enjoy your city where you presumably don’t want to pay for police because they’re so expensive.\"</p><p><a href=\"https://anildash.com/2011/07/20/if_your_websites_full_of_assholes_its_your_fault-2/\" rel=\"nofollow noopener noreferrer\" target=\"_blank\"><span class=\"invisible\">https://</span><span class=\"ellipsis\">anildash.com/2011/07/20/if_you</span><span class=\"invisible\">r_websites_full_of_assholes_its_your_fault-2/</span></a></p>")

        let result = try html.mastodonAttributedString
//        print("###############################################")
//        print(html.rawValue.replacing("<br />", with: "<br>\n"))
        print(result)
    }
}

