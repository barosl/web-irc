sortedIndex = (arr, val) ->
    low = 0
    high = arr.length
    while low < high
        mid = (low + high) >>> 1
        if arr[mid] < val then low = mid + 1 else high = mid
    return low

parse_irc_msg = (msg) ->
    mat = msg.match /(:(\S+)\s+)?(\S+)((\s+(:[^\r\n]*|\S+))*)/
    if not mat then return null

    prefix = mat[2] ? null
    cmd = mat[3].toLowerCase()
    params_s = mat[4]

    params = []

    regexp = /\s+(:([^\r\n]*)|(\S+))/g
    while (mat = regexp.exec params_s) != null
        if mat[2] == undefined then params.push mat[3]
        else params.push mat[2]

    return [prefix, cmd, params]

get_irc_msg = (cmd, params, prefix=null) ->
    return \
        (if prefix then ':'+prefix+' ' else '') \
        + cmd.toUpperCase() \
        + (' ' +
            if params
            then (params[...-1].concat(
                if ' ' in params[params.length-1]
                then ':'+params[params.length-1]
                else params[params.length-1]
                )).join(' ') \
            else '' \
        )

this.irclib =
    parse_irc_msg: parse_irc_msg
    get_irc_msg: get_irc_msg

    IRC: class
        constructor: (@sender) ->
            @handlers = {}
            @nick = null
            @chans = {}
            @modes = {}

        emit: (type, ev={}) ->
            funcs = @handlers[type]
            if funcs
                for func in funcs then func.call this, ev

        add_handler: (type, func) ->
            @handlers[type] ?= []
            @handlers[type].push func

        add_handlers: (funcs) ->
            for type, func of funcs
                @add_handler type, func

        send: (cmd, params, prefix=null) ->
            @sender get_irc_msg cmd, params, prefix

        parse: (buf) ->
            lines = buf.match /[^\r\n]+/g
            for line in lines
                @parse_line line

        parse_line: (line) ->
            res = parse_irc_msg line

            if res
                [prefix, cmd, params] = res

                if prefix and '!' in prefix
                    nick = prefix[...prefix.indexOf('!')]
                else nick = null
            else cmd = null

            if cmd == 'privmsg'
                @emit 'msg', {prefix: prefix, nick: nick, chan: params[0], msg: params[1]}

            else if cmd == 'join'
                chan = params[0].toLowerCase()

                if nick != @nick
                    pos = sortedIndex @chans[chan], nick
                    @chans[chan][pos...pos] = [nick]
                    @modes[chan][nick] = ''
                else
                    @chans[chan] = []
                    @modes[chan] = {}

                @emit 'join', {prefix: prefix, nick: nick, chan: chan}

            else if cmd == 'part'
                chan = params[0].toLowerCase()
                reason = if params.length > 1 then params[1] else ''

                if nick != @nick
                    pos = @chans[chan].indexOf nick
                    if ~pos
                        @chans[chan][pos..pos] = []
                        delete @modes[chan][nick]
                else
                    delete @chans[chan]
                    delete @modes[chan]

                @emit 'part', {prefix: prefix, nick: nick, chan: chan, reason: reason}

            else if cmd == 'quit'
                reason = if params.length > 0 then params[0] else ''

                if nick == @nick
                    @chans = {}
                    @modes = {}

                @emit 'quit', {prefix: prefix, nick: nick, reason: reason}

            else if cmd == 'kick'
                chan = params[0].toLowerCase()
                reason = if params.length > 2 then params[2] else ''

                if nick == @nick
                    delete @chans[chan]
                    delete @modes[chan]

                @emit 'kick', {prefix: prefix, nick: nick, chan: chan, target: params[1], reason: reason}

            else if cmd == 'nick'
                new_nick = params[0]

                if nick == @nick then @nick = new_nick

                for chan of @chans
                    pos = @chans[chan].indexOf nick
                    if ~pos
                        @chans[chan][pos..pos] = []

                    mode = ''
                    if @modes[chan][nick]?
                        mode = @modes[chan][nick]
                        delete @modes[chan][nick]

                    pos = sortedIndex @chans[chan], new_nick
                    @chans[chan][pos...pos] = [new_nick]
                    @modes[chan][new_nick] = mode

                @emit 'nick', {prefix: prefix, nick: nick, new_nick: new_nick}

            else if cmd == 'mode'
                chan = params[0]
                modes_s = params[1]
                mode_params = params[2..]
                mode_param_idx = 0

                [sign, modes] = [modes_s[0] == '+', modes_s[1..]]

                for mode in modes
                    mode_param = if mode in 'ov' then mode_params[mode_param_idx++] else null

                    if mode == 'o'
                        if @modes[chan][mode_param] != 'o' or mode == 'o'
                            @modes[chan][mode_param] = if sign then mode else ''

            else if cmd == 'ping'
                @send 'pong', params

            else if cmd == '001'
                @nick = params[0]

                @emit 'welcome'

            else if cmd == '433'
                @emit 'err', {cmd: cmd, msg: params[2]}

            else if cmd == '353'
                chan = params[2].toLowerCase()
                nicks_s = params[3]

                regexp = /([@+])?(\S+)/g
                while (mat = regexp.exec nicks_s) != null
                    mode = mat[1]
                    nick = mat[2]

                    pos = sortedIndex @chans[chan], nick
                    @chans[chan][pos...pos] = [nick]
                    @modes[chan][nick] = if mode == '@' then 'o' else if mode == '+' then 'v' else ''

            else if cmd == '366'
                chan = params[1].toLowerCase()

                @emit 'users', {chan: chan, nicks: @chans[chan][..]}

            else
                console.warn 'Invalid server response: '+line

        join: (chan) ->
            @send 'join', [chan]

        part: (chan) ->
            @send 'part', [chan]

        set_nick: (new_nick) ->
            @send 'nick', [new_nick]

        user: (username, realname) ->
            @send 'user', [username, 'hostname', 'servername', realname]

        msg: (msg, chan) ->
            @send 'privmsg', [chan, msg]

        get_mode: (chan, nick) ->
            return @modes[chan.toLowerCase()][nick]
