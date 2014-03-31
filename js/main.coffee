RECONN_SECS = 5
DEFAULT_CHAN = if mat = /[?&]chan=([^&]+)/.exec location.search then '#'+mat[1] else '#default'
VERBOSE = /[?&]verbose=(true|1)&?/.test location.search

sortedIndex = (arr, val) ->
    low = 0
    high = arr.length
    while low < high
        mid = (low + high) >>> 1
        if arr[mid] < val then low = mid + 1 else high = mid
    return low

$ ->
    [sock, user, connected, users] = []
    init = ->
        sock = null
        user = {}

        connected = false
        $('#chat-nick').prop 'disabled', true

        users = []
        $('#chat-users').empty()
        update_user_cnt()

    chat_body_el = $('#chat-body')[0]
    chat_users_butt_el = $('#chat-users-butt')[0]

    send = (data) -> sock.send JSON.stringify data

    set_nick = (nick) ->
        set_nick.desired_nick = nick
        send nick: nick

    conn = ->
        sock = new WebSocket cfg.url

        sock.onopen = (ev) ->
            connected = true
            $('#chat-nick').prop 'disabled', false

            add_msg 'Successfully connected', 'info'

            nick = localStorage.chat_nick ? ''
            set_nick nick
            $('#chat-nick').val nick

        sock.onclose = (ev) ->
            init()

            add_msg "Connection closed. Reconnecting in #{RECONN_SECS} seconds (Error code: #{ev.code})", 'err'

            setTimeout ->
                conn()
            , RECONN_SECS*1000

        sock.onmessage = (ev) ->
            err = false

            try data = JSON.parse ev.data
            catch then err = true

            if not err
                if 'msg' of data
                    add_msg data.msg
                else if 'nick' of data
                    if not user.nick?
                        send join: DEFAULT_CHAN
                    if data.user
                        if VERBOSE then add_msg "#{data.user} is now known as #{data.nick}", 'info'
                        else add_msg "#{data.user} -> #{data.nick}", 'info'

                        pos = users.indexOf data.user
                        if ~pos
                            users[pos..pos] = []
                            remove_el pos, '#chat-users p'

                            idx = sortedIndex users, data.nick

                            insert_el idx, '#chat-users p', users, get_user_el data.nick
                            users[idx...idx] = [data.nick]
                            update_user_cnt()
                        else console.error 'Unable to find the user in the user list'
                    else
                        user.nick = data.nick
                        $('#chat-nick').val user.nick
                else if 'err' of data
                    $('#chat-nick').val user.nick ? localStorage.chat_nick
                    add_msg data.err, 'err'

                    if data.err == 'Nickname already in use'
                        set_nick set_nick.desired_nick+~~(Math.random()*10)
                else if 'users' of data
                    users = data.users
                    users.sort()

                    frag = document.createDocumentFragment()
                    for nick in users
                        frag.appendChild get_user_el nick

                    $('#chat-users').empty().append frag
                    update_user_cnt()
                else if 'msgs' of data
                    add_msgs data.msgs
                else if 'join' of data
                    if VERBOSE then add_msg "#{data.user} has joined #{data.join}", 'info'
                    if data.user != user.nick
                        idx = sortedIndex users, data.user

                        insert_el idx, '#chat-users p', users, get_user_el data.user
                        users[idx...idx] = [data.user]
                        update_user_cnt()
                else if 'part' of data
                    if VERBOSE then add_msg "#{data.user} has parted #{data.part}", 'info'
                    if data.user != user.nick
                        pos = users.indexOf data.user
                        if ~pos
                            users[pos..pos] = []
                            remove_el pos, '#chat-users p'
                            update_user_cnt()
                        else console.error 'Unable to find the user in the user list'
                    else
                        users = []
                        $('#chat-users').empty()
                        update_user_cnt()
                else if 'reload' of data
                    location.reload true
                else err = true

            if err
                add_msg 'Invalid server response', 'err'
                console.log "Invalid server response: #{ev.data}"

    $('#chat-input').keydown (ev) ->
        if ev.which != 13 or ev.target.value == '' then return
        ev.preventDefault()
        [msg, ev.target.value] = [ev.target.value, '']

        msg = $.trim msg
        if not msg then return

        if not connected
            add_msg 'Not connected', 'err'
            return

        if msg == '/join'
            send join: DEFAULT_CHAN
        else if msg == '/part'
            send part: DEFAULT_CHAN
        else
            send msg: msg, chan: DEFAULT_CHAN

    $('#chat-nick').keydown (ev) ->
        if ev.which != 13 or $('#chat-nick').val() == (user.nick ? null) then return
        ev.preventDefault()

        if $('#chat-nick').val() == ''
            $('#chat-nick').val user.nick ? localStorage.chat_nick ? ''
            $('#chat-input').focus()
            return

        set_nick $('#chat-nick').val()

        localStorage.chat_nick = $('#chat-nick').val()

        localStorage.update() if ie_7?

        $('#chat-input').focus()

    $('#chat-users-butt').click (ev) ->
        ev.preventDefault()
        $('#chat-users').toggle()

    insert_el = (idx, selector, list, el) ->
        if idx != list.length
            $("#{selector}:nth-child(#{idx+1})").before el
        else
            $("#{selector}:nth-child(#{idx})").after el

    remove_el = (idx, selector) ->
        $("#{selector}:nth-child(#{idx+1})").remove()

    get_user_el = (nick) ->
        p_el = document.createElement 'p'
        p_el.appendChild document.createTextNode nick
        return p_el

    update_user_cnt = ->
        chat_users_butt_el.firstChild.nodeValue = chat_users_butt_el.getAttribute('data-text').replace '{}', users.length

    is_bottom = -> ((x) -> x.scrollTop + $(x).outerHeight() == x.scrollHeight) chat_body_el
    scroll = -> ((x) -> x.scrollTop = x.scrollHeight) chat_body_el

    get_msg_el = (msg, type) ->
        p_el = document.createElement 'p'
        p_el.appendChild document.createTextNode msg
        p_el.className = type
        return p_el

    add_msg = (msg, type='normal') ->
        flag = is_bottom()
        chat_body_el.appendChild get_msg_el msg, type
        if flag then scroll()

    add_msgs = (msgs) ->
        flag = is_bottom()
        for msg in msgs
            add_msg msg
        if flag then scroll()

    init()
    conn()
    $('#chat-input').focus()
