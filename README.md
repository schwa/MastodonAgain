# MastodonAgain

I did a bad thing.

![](Documentation/Screenshot%202022-10-30%20at%2022.38.35.png)

## What works?

- [X] Login (using an authentication code)
- [X] Timeline (to some extent)
- [X] Favouriting
- [X] Reposting
- [X] Posting & replying.
- [X] Image uploading

## What needs help?

- [BUG] The @Store PropertyWrapper isn't working inside a ObservableObject and now life sucks.
- [BUG] Hitting the new post window when multiple account timelines are open - picks a random account to post from
- Timeline "infinite scroll". SwiftUI probably isn't going to work here.
- ... button
  - Delete post
  - All the other actions
  - Open in browser
  - Disable reposts
- A real API - right now Service.swift is just a bunch of hard coded GET/POST URLRequests. I have some experiments going on in jwight/wip branch to improve this
- A real Status Detail view - right now just shows JSON :-)
- A real Account Detail view - again just ~~JSON~~ basic placeholder UI
- A thread view
- Add robust fail handling to Posting - including Drafts
- Places for pinned tweets
- Local timeline search/filtering
- Remote search
- Better caching and persistence
- Intercept clicks on the content links (rewrite the links on the attributed strings? add a onURL handler)
- Better handling of content warnings
- Make the mini timeline view more useful - remove CRLF etc
- Get the markdown content mode working
- Fix contextual menus in timeline - right now there's a lot of fighting between taps for selection, onTap and context menus
- Build and run on iOS
- Improve image posting UX
- Instance switcher
