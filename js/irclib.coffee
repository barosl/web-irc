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

get_irc_msg = (cmd, params=[], prefix=null) ->
    return \
        (if prefix then ':'+prefix+' ' else '') \
        + cmd.toUpperCase() \
        + (' ' +
            if params and params.length
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
            @nicks = {}
            @nicks_k = {}
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

        send: (cmd, params=[], prefix=null) ->
            @sender get_irc_msg cmd, params, prefix

        parse: (buf) ->
            lines = buf.match /[^\r\n]+/g
            if not lines then return
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
                chan = params[0]
                chan_k = chan.toLowerCase()

                nick_k = '1'+nick.toLowerCase()

                if nick != @nick
                    pos = sortedIndex @nicks_k[chan_k], nick_k
                    @nicks[chan_k][pos...pos] = [nick]
                    @nicks_k[chan_k][pos...pos] = [nick_k]
                    @modes[chan_k][nick] = ''
                else
                    @nicks[chan_k] = []
                    @nicks_k[chan_k] = []
                    @modes[chan_k] = {}

                @emit 'join', {prefix: prefix, nick: nick, chan: chan}

            else if cmd == 'part'
                chan = params[0]
                chan_k = chan.toLowerCase()
                reason = if params.length > 1 then params[1] else ''

                if nick != @nick
                    pos = @nicks[chan_k].indexOf nick
                    if ~pos
                        @nicks[chan_k][pos..pos] = []
                        @nicks_k[chan_k][pos..pos] = []
                        delete @modes[chan_k][nick]
                else
                    delete @nicks[chan_k]
                    delete @nicks_k[chan_k]
                    delete @modes[chan_k]

                @emit 'part', {prefix: prefix, nick: nick, chan: chan, reason: reason}

            else if cmd == 'quit'
                reason = if params.length > 0 then params[0] else ''

                if nick == @nick
                    @nicks = {}
                    @nicks_k = {}
                    @modes = {}

                @emit 'quit', {prefix: prefix, nick: nick, reason: reason}

            else if cmd == 'kick'
                chan = params[0]
                chan_k = chan.toLowerCase()
                reason = if params.length > 2 then params[2] else ''

                if nick == @nick
                    delete @nicks[chan_k]
                    delete @nicks_k[chan_k]
                    delete @modes[chan_k]

                @emit 'kick', {prefix: prefix, nick: nick, chan: chan, target: params[1], reason: reason}

            else if cmd == 'nick'
                new_nick = params[0]

                if nick == @nick then @nick = new_nick

                for chan of @nicks
                    pos = @nicks[chan].indexOf nick
                    if ~pos
                        @nicks[chan][pos..pos] = []
                        @nicks_k[chan][pos..pos] = []

                    mode = ''
                    if @modes[chan][nick]?
                        mode = @modes[chan][nick]
                        delete @modes[chan][nick]

                    new_nick_k = +(mode != 'o')+new_nick.toLowerCase()

                    pos = sortedIndex @nicks_k[chan], new_nick_k
                    @nicks[chan][pos...pos] = [new_nick]
                    @nicks_k[chan][pos...pos] = [new_nick_k]
                    @modes[chan][new_nick] = mode

                @emit 'nick', {prefix: prefix, nick: nick, new_nick: new_nick}

            else if cmd == 'mode'
                chan = params[0]
                chan_k = chan.toLowerCase()
                modes_s = params[1]
                mode_params = params[2..]
                mode_param_idx = 0

                if chan[0] != '#' then return

                [sign, modes_l] = [modes_s[0] == '+', modes_s[1..]]

                modes = []

                for mode in modes_l
                    mode_param = if mode in 'ov' then mode_params[mode_param_idx++] else null

                    modes.push([mode, mode_param])

                    if mode in 'ov'
                        nick = mode_param

                        if mode == 'o'
                            prev_label = +(@modes[chan_k][nick] != 'o')
                            label = 1-+sign

                            if prev_label != label
                                nick_k = label + nick.toLowerCase()

                                pos = @nicks[chan].indexOf nick
                                if ~pos
                                    @nicks[chan][pos..pos] = []
                                    @nicks_k[chan][pos..pos] = []

                                pos = sortedIndex @nicks_k[chan], nick_k
                                @nicks[chan][pos...pos] = [nick]
                                @nicks_k[chan][pos...pos] = [nick_k]

                        if @modes[chan_k][nick] != 'o' or mode == 'o'
                            @modes[chan_k][nick] = if sign then mode else ''

                @emit 'mode', {chan: chan, sign: sign, modes: modes}

            else if cmd == 'ping'
                @send 'pong', params

            else if cmd == '001'
                @nick = params[0]

                @emit 'welcome'

            else if cmd == '433'
                @emit 'err', {cmd: cmd, msg: params[2]}

            else if cmd == '353'
                chan = params[2]
                chan_k = chan.toLowerCase()
                nicks_s = params[3]

                regexp = /([@+])?(\S+)/g
                while (mat = regexp.exec nicks_s) != null
                    mode = mat[1]
                    nick = mat[2]

                    nick_k = +(mode != '@')+nick.toLowerCase()

                    pos = sortedIndex @nicks_k[chan_k], nick_k
                    @nicks[chan_k][pos...pos] = [nick]
                    @nicks_k[chan_k][pos...pos] = [nick_k]
                    @modes[chan_k][nick] = if mode == '@' then 'o' else if mode == '+' then 'v' else ''

            else if cmd == '366'
                chan = params[1]
                chan_k = chan.toLowerCase()

                @emit 'users', {chan: chan, nicks: @nicks[chan_k][..]}

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
