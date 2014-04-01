RECONN_SECS = 5
SCROLLBACK_BUFFER_SIZE = 2000

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
    [sock, connected, users, irc] = []
    init = ->
        sock = null

        irc = new irclib.IRC (line) -> sock.send line + '\n'
        irc.add_handlers
            welcome: on_welcome
            nick: on_nick
            join: on_join
            part: on_part
            quit: on_quit
            kick: on_kick
            users: on_users
            msg: on_msg
            err: on_err

        connected = false
        $('#chat-nick').prop 'disabled', true

        users = []
        $('#chat-users').empty()
        update_user_cnt()

    chat_body_el = $('#chat-body')[0]
    chat_users_butt_el = $('#chat-users-butt')[0]

    set_nick = (nick) ->
        set_nick.desired_nick = nick
        irc.set_nick nick

    conn = ->
        sock = new WebSocket cfg.url

        sock.onopen = (ev) ->
            connected = true
            $('#chat-nick').prop 'disabled', false

            add_msg 'Successfully connected', 'info'

            irc.user 'web-irc', 'WebIRC Lee'

            nick = if localStorage.chat_nick then localStorage.chat_nick else 'User'
            set_nick nick
            $('#chat-nick').val nick

        sock.onclose = (ev) ->
            init()

            add_msg "Connection closed. Reconnecting in #{RECONN_SECS} seconds (Error code: #{ev.code})", 'err'

            setTimeout ->
                conn()
            , RECONN_SECS*1000

        sock.onmessage = (ev) ->
            irc.parse ev.data

    on_welcome = ->
        $('#chat-nick').val irc.nick

        irc.join DEFAULT_CHAN

    on_nick = (ev) ->
        if VERBOSE then add_msg "#{ev.nick} is now known as #{ev.new_nick}", 'info'
        else add_msg "#{ev.nick} -> #{ev.new_nick}", 'info'

        pos = users.indexOf ev.nick
        if ~pos
            users[pos..pos] = []
            el = detach_el pos, '#chat-users p'

            idx = sortedIndex users, ev.new_nick

            el.firstChild.nodeValue = ev.new_nick
            insert_el idx, '#chat-users p', users, el
            users[idx...idx] = [ev.new_nick]
            update_user_cnt()
        else console.error 'Unable to find the user in the user list'

    on_join = (ev) ->
        if VERBOSE or ev.nick == irc.nick then add_msg "#{ev.nick} has joined #{ev.chan}", 'info'

        if ev.nick != irc.nick
            idx = sortedIndex users, ev.nick

            insert_el idx, '#chat-users p', users, get_user_el ev.nick
            users[idx...idx] = [ev.nick]
            update_user_cnt()

    on_part = (ev) ->
        if VERBOSE or ev.nick == irc.nick then add_msg "#{ev.nick} has parted #{ev.chan} (Reason: #{ev.reason})", 'warn'

        if ev.nick != irc.nick
            pos = users.indexOf ev.nick
            if ~pos
                users[pos..pos] = []
                remove_el pos, '#chat-users p'
                update_user_cnt()
            else console.error 'Unable to find the user in the user list'
        else
            users = []
            $('#chat-users').empty()
            update_user_cnt()

    on_quit = (ev) ->
        if VERBOSE or ev.nick == irc.nick then add_msg "#{ev.nick} has quited (Reason: #{ev.reason})", 'warn'

        if ev.nick != irc.nick
            pos = users.indexOf ev.nick
            if ~pos
                users[pos..pos] = []
                remove_el pos, '#chat-users p'
                update_user_cnt()
            else console.error 'Unable to find the user in the user list'
        else
            users = []
            $('#chat-users').empty()
            update_user_cnt()

    on_kick = (ev) ->
        add_msg "#{ev.nick} has kicked #{ev.target} (Reason: #{ev.reason})", 'err'

        if ev.target != irc.nick
            pos = users.indexOf ev.target
            if ~pos
                users[pos..pos] = []
                remove_el pos, '#chat-users p'
                update_user_cnt()
            else console.error 'Unable to find the user in the user list'
        else
            users = []
            $('#chat-users').empty()
            update_user_cnt()

    on_users = (ev) ->
        users = ev.nicks
        users.sort()

        frag = document.createDocumentFragment()
        for nick in users
            frag.appendChild get_user_el nick

        $('#chat-users').empty().append frag
        update_user_cnt()

    on_msg = (ev) ->
        add_msg {msg: ev.msg, nick: ev.nick}

        if this.has_op ev.nick, ev.chan
            if ev.msg == '!reload'
                location.reload true

    on_err = (ev) ->
        add_msg ev.msg, 'err'

        if ev.cmd == '433'
            $('#chat-nick').val irc.nick ? localStorage.chat_nick ? ''
            set_nick set_nick.desired_nick+~~(Math.random()*10)

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
            irc.join DEFAULT_CHAN
        else if msg == '/part'
            irc.part DEFAULT_CHAN
        else
            irc.msg msg, DEFAULT_CHAN

            add_msg {msg: msg, nick: irc.nick}, 'my'

    $('#chat-nick').keydown (ev) ->
        if ev.which != 13 or $('#chat-nick').val() == (irc.nick ? null) then return
        ev.preventDefault()

        if $('#chat-nick').val() == ''
            $('#chat-nick').val irc.nick ? localStorage.chat_nick ? ''
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

    detach_el = (idx, selector) ->
        return $("#{selector}:nth-child(#{idx+1})").detach()[0]

    get_user_el = (nick) ->
        p_el = document.createElement 'p'
        p_el.appendChild document.createTextNode nick
        return p_el

    update_user_cnt = ->
        chat_users_butt_el.firstChild.nodeValue = chat_users_butt_el.getAttribute('data-text').replace '{}', users.length

    SCROLL_MARGIN = 50
    is_bottom = -> ((x) -> x.scrollTop + $(x).outerHeight() + SCROLL_MARGIN >= x.scrollHeight) chat_body_el
    scroll = -> ((x) -> x.scrollTop = x.scrollHeight) chat_body_el

    get_msg_el = (msg, type) ->
        p_el = document.createElement 'p'
        p_el.className = type

        if typeof msg == 'string'
            p_el.appendChild document.createTextNode msg
        else
            nick_el = document.createElement 'span'
            nick_el.className = 'nick'
            nick_el.appendChild document.createTextNode msg.nick

            msg_el = document.createElement 'span'
            msg_el.className = 'msg'
            msg_el.appendChild document.createTextNode msg.msg

            p_el.appendChild nick_el
            p_el.appendChild document.createTextNode ': '
            p_el.appendChild msg_el

        return p_el

    add_msg = (msg, type='normal') ->
        flag = is_bottom()

        while chat_body_el.childNodes.length > SCROLLBACK_BUFFER_SIZE - 1
            if not flag
                chat_body_el.scrollTop -= \
                    chat_body_el.childNodes[1].offsetTop \
                    - chat_body_el.firstChild.offsetTop

            chat_body_el.removeChild chat_body_el.firstChild

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
