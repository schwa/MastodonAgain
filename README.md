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

- Timeline "infinite scroll". SwiftUI probably isn't going to work here.
- All the action buttons need to be hooked up.
- ... button
  - Delete post
  - All the other actions
  - Open in browser
  - Disable reposts
- A real API - right now Service.swift is just a bunch of hard coded GET/POST URLRequests. I have some experiments going on in jwight/wip branch to improve this
- A real Status Detail view - right now just shows JSON :-)
- A real Account Detail view - again just JSON :-)
- A thread view
- Add robust fail handling to Posting - including Drafts
- Places for pinned tweets
- Local timeline search/filtering
- Remote search
- Better caching and persistence
