RECONN_SECS = 5
DEFAULT_CHAN = if mat = /[?&]chan=([^&]+)/.exec location.search then '#'+mat[1] else '#default'
VERBOSE = /[?&]verbose=(true|1)&?/.test location.search

angular.module 'chat', ['ngSanitize']
    .config ($sceProvider) ->
        $sceProvider.enabled false if ie_7?

    .controller 'ChatCtrl', ($scope) ->
        $scope.init = ->
            $scope.connected = false
            $scope.nick = ''
            $scope.users = []
        $scope.init()

        $scope.msgs = []

$ ->
    $scope = angular.element('#chat').scope()

    [sock, user] = []
    init = ->
        sock = null
        user = {}
    init()

    send = (data) -> sock.send JSON.stringify data

    set_nick = (nick) ->
        set_nick.desired_nick = nick
        send nick: nick

    conn = ->
        sock = new WebSocket cfg.url

        sock.onopen = (ev) ->
            $scope.$apply -> $scope.connected = true

            add_msg 'Successfully connected', 'info'

            nick = localStorage.chat_nick ? ''
            set_nick nick
            $scope.$apply -> $scope.nick = nick

        sock.onclose = (ev) ->
            $scope.$apply -> $scope.init()

            add_msg "Connection closed. Reconnecting in #{RECONN_SECS} seconds (Error code: #{ev.code})", 'err'

            setTimeout ->
                conn()
            , RECONN_SECS*1000

        sock.onmessage = (ev) ->
            try
                data = JSON.parse ev.data

                if 'msg' of data
                    add_msg data.msg
                else if 'nick' of data
                    if not user.nick?
                        send join: DEFAULT_CHAN
                    if data.user
                        if VERBOSE then add_msg "#{data.user} is now known as #{data.nick}", 'info'
                        $scope.$apply ->
                            pos = $scope.users.indexOf data.user
                            if pos == -1 then console.error 'Unable to find user in user list'
                            else $scope.users[pos] = data.nick
                    else
                        user.nick = data.nick
                        $scope.$apply -> $scope.nick = user.nick
                else if 'err' of data
                    $scope.$apply -> $scope.nick = user.nick ? localStorage.chat_nick
                    add_msg data.err, 'err'

                    if data.err == 'Nickname already in use'
                        set_nick set_nick.desired_nick+'+'
                else if 'users' of data
                    $scope.$apply -> $scope.users = data.users
                else if 'msgs' of data
                    add_msgs data.msgs
                else if 'join' of data
                    if VERBOSE then add_msg "#{data.user} has joined #{data.join}", 'info'
                else if 'part' of data
                    if VERBOSE then add_msg "#{data.user} has parted #{data.part}", 'info'
                    if data.user == user.nick
                        $scope.$apply -> $scope.users = []
                else
                    throw new SyntaxError 'Invalid message type'

            catch e
                add_msg 'Invalid server response', 'err'
                console.log "Invalid server response: #{ev.data}"

    $('#chat-input').keydown (ev) ->
        if ev.which != 13 or ev.target.value == '' then return
        ev.preventDefault()
        [msg, ev.target.value] = [ev.target.value, '']

        msg = $.trim(msg)
        if not msg then return

        if not $scope.connected
            add_msg 'Not connected', 'err'
            return

        if msg == '/join'
            send join: DEFAULT_CHAN
        else if msg == '/part'
            send part: DEFAULT_CHAN
        else
            send msg: msg, chan: DEFAULT_CHAN

    $('#chat-nick').keydown (ev) ->
        if ev.which != 13 or $scope.nick == (user.nick ? null) then return
        ev.preventDefault()

        ###
        if $scope.nick == ''
            $scope.$apply -> $scope.nick = user.nick ? localStorage.chat_nick ? ''
            $('#chat-input').focus()
            return
        ###

        set_nick $scope.nick

        localStorage.chat_nick = $scope.nick

        localStorage.update() if ie_7?

        $('#chat-input').focus()

    $('#chat-users-butt').click (ev) ->
        ev.preventDefault()
        $('#chat-users').toggle()

    add_msg = (msg, type='normal') ->
        $scope.$apply -> $scope.msgs.push type: type, msg: msg
        ((x) -> x.scrollTop = x.scrollHeight) $('#chat-body')[0]

    add_msgs = (msgs) ->
        $scope.$apply -> Array::push.apply $scope.msgs, (type: 'normal', msg: x for x in msgs)
        ((x) -> x.scrollTop = x.scrollHeight) $('#chat-body')[0]

    conn()
    $('#chat-input').focus()
