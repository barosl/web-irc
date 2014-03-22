RECONN_SECS = 5

angular.module 'chat', []
    .config ($sceProvider) ->
        $sceProvider.enabled false if ie_7?

    .controller 'ChatCtrl', ($scope) ->
        $scope.connected = false
        $scope.nick = ''
        $scope.users = []
        $scope.msgs = []

$ ->
    $scope = angular.element($('body')).scope()

    sock = null
    user =
        nick: ''

    send = (data) -> sock.send JSON.stringify data

    conn = ->
        sock = new WebSocket cfg.url

        sock.onopen = (ev) ->
            $scope.$apply -> $scope.connected = true

            add_msg 'Successfully connected'

        sock.onclose = (ev) ->
            $scope.$apply -> $scope.connected = false

            add_msg "Connection closed. Reconnecting in #{RECONN_SECS} seconds (Error code: #{ev.code})"

            setTimeout ->
                conn()
            , RECONN_SECS*1000

        sock.onmessage = (ev) ->
            try
                data = JSON.parse ev.data

                if 'msg' of data
                    add_msg data.msg
                else if 'nick' of data
                    user.nick = data.nick
                    $scope.$apply -> $scope.nick = user.nick
                else if 'err' of data
                    $scope.$apply -> $scope.nick = user.nick
                    add_msg data.err
                else if 'users' of data
                    $scope.$apply -> $scope.users = data.users
                else if 'msgs' of data
                    set_msgs data.msgs
                else
                    throw new SyntaxError 'Invalid message type'

            catch e
                add_msg 'Invalid server response'
                console.log "Invalid server response: #{ev.data}"

    $('#chat-input').keydown (ev) ->
        if ev.which != 13 or ev.target.value == '' then return
        ev.preventDefault()
        [msg, ev.target.value] = [ev.target.value, '']

        msg = $.trim(msg)
        if not msg then return

        if not $scope.connected
            add_msg 'Not connected'
            return

        send msg: msg

    $('#chat-nick').keydown (ev) ->
        if ev.which != 13 or $scope.nick == user.nick then return
        ev.preventDefault()

        if $scope.nick == ''
            $scope.$apply -> $scope.nick = user.nick
            $('#chat-input').focus()
            return

        send nick: $scope.nick

        $scope.$apply -> $scope.nick = user.nick

        $('#chat-input').focus()

    $('#users-link').click (ev) ->
        ev.preventDefault()
        $('#users').toggle()

    add_msg = (msg) ->
        $scope.$apply -> $scope.msgs.push msg
        window.scrollTo 0, document.body.scrollHeight

    set_msgs = (msgs) ->
        $scope.$apply -> $scope.msgs = msgs
        window.scrollTo 0, document.body.scrollHeight

    conn()
    $('#chat-input').focus()
