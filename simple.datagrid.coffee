$ = @jQuery


slugify = (string) ->
    return string.replace(/\s+/g,'-').replace(/[^a-zA-Z0-9\-]/g,'').toLowerCase()

buildUrl = (url, query_parameters) ->
    result = url

    is_first = true
    for key, value of query_parameters
        if is_first
            result += '?'
            is_first = false
        else
            result += '&'

        result += "#{ key }=#{ value }"

    return result

@SimpleDataGrid =
    slugify: slugify
    buildUrl: buildUrl


$.widget("ui.simple_datagrid", {
    options:
        onGetData: null

    _create: ->
        @url = @_getBaseUrl()
        @$selected_row = null
        @current_page = 1
        @parameters = {}

        @_generateColumnData()
        @_createDomElements()
        @_bindEvents()
        @_loadData()

    destroy: ->
        @_removeDomElements()
        @_removeEvents()

        $.Widget.prototype.destroy.call(this)

    getSelectedRow: ->
        if @$selected_row
            return @$selected_row.data('row')
        else
            return null

    reload: ->
        @_loadData()

    setParameter: (key, value) ->
        @parameters[key] = value

    getColumns: ->
        return @columns

    _generateColumnData: ->
        generateFromThElements = =>
            $th_elements = @element.find('th')
            @columns = []
            $th_elements.each(
                (i, th) =>
                    $th = $(th)

                    title = $th.text()
                    key = $th.data('key') or slugify(title)

                    @columns.push(
                        {title: title, key: key}
                    )
            )

        generateFromOptions = =>
            @columns = []
            for column in @options.columns
                if typeof column == 'object'
                    column_info = {
                        title: column.title,
                        key: column.key,
                        on_generate: column.on_generate
                    }
                else
                    column_info = {
                        title: column,
                        key: slugify(column)
                    }

                @columns.push(column_info)

        if @options.columns
            generateFromOptions()
        else
            generateFromThElements()

    _createDomElements: ->
        initTable = =>
            @element.addClass('simple-data-grid')

        initBody = =>
            @$tbody = @element.find('tbody')

            if @$tbody.length
                @$tbody.empty()
            else
                @$tbody = $('<tbody></tbody>')
                @element.append(@$tbody)

        initFoot = =>
            @$tfoot = @element.find('tfoot')

            if @$tfoot.length
                @$tfoot.empty()
            else
                @$tfoot = $('<tfoot></tfoot>')
                @element.append(@$tfoot)

        initHead = =>
            @$thead = @element.find('thead')

            if @$thead.length
                @$thead.empty()
            else
                @$thead = $('<thead></thead>')
                @element.append(@$thead)

            html = '<tr>'
            for column in @columns
                html += "<th data-key=\"#{ column.key }\">#{ column.title }</th>"

            html += '</tr>'
            @$thead.append($(html))

        initTable()
        initHead()
        initBody()
        initFoot()

    _removeDomElements: ->
        @element.removeClass('simple-data-grid')
        @$tbody.remove()
        @$tbody = null

    _bindEvents: ->
        @element.delegate('tbody tr', 'click', $.proxy(this._clickRow, this))
        @element.delegate('.paginator .first', 'click', $.proxy(this._handleClickFirstPage, this))
        @element.delegate('.paginator .previous', 'click', $.proxy(this._handleClickPreviousPage, this))
        @element.delegate('.paginator .next', 'click', $.proxy(this._handleClickNextPage, this))
        @element.delegate('.paginator .last', 'click', $.proxy(this._handleClickLastPage, this))

    _removeEvents: ->
        @element.undelegate('tbody tr', 'click')
        @element.undelegate('.paginator .first', 'click')
        @element.undelegate('.paginator .previous', 'click')
        @element.undelegate('.paginator .next', 'click')
        @element.undelegate('.paginator .last', 'click')

    _getBaseUrl: ->
        url = @options.url
        if url
            return url
        else
            return @element.data('url')

    _clickRow: (e) ->
        if @$selected_row
            @$selected_row.removeClass('selected')

        $tr = $(e.target).closest('tr')
        $tr.addClass('selected')
        @$selected_row = $tr

        event = $.Event('datagrid.select')
        @element.trigger(event)

    _loadData: ->
        query_parameters = $.extend({}, @parameters, {page: @current_page})

        getDataFromCallback = =>
            @options.onGetData(
                query_parameters,
                $.proxy(@_fillGrid, this)
            )

        getDataFromUrl = =>
            url = buildUrl(
                @paginator.url,
                query_parameters
            )

            $.ajax(
                url: url,
                success: (result) =>
                    @_fillGrid(result)
                , datatType: 'json',
                cache: false
            )

        getDataFromArray = =>
            @_fillGrid(@options.data)

        if @options.onGetData
            getDataFromCallback()
        else if @url
            getDataFromUrl()
        else if @options.data
            getDataFromArray()

    _fillGrid: (data) ->
        addRowFromObject = (row) =>
            html = ''
            for column in @columns
                if column.key of row
                    value = row[column.key]

                    if column.on_generate
                        value = column.on_generate(value, row)
                else
                    value = ''

                html += "<td>#{ value }</td>"

            return html

        addRowFromArray = (row) =>
            html = ''

            for value, i in row
                column = @columns[i]

                if column.on_generate
                    value = column.on_generate(value, row)

                html += "<td>#{ value }</td>"

            return html

        generateTr = (row) =>
            if row.id
                data_string = " data-id=\"#{ row.id }\""
            else
                data_string = ""

            return "<tr#{ data_string }>"

        fillRows = (rows) =>
            @$tbody.empty()

            for row in rows
                html = generateTr(row)

                if $.isArray(row)
                    html += addRowFromArray(row)
                else
                    html += addRowFromObject(row)

                html += '</tr>'
                $tr = $(html)
                $tr.data('row', row)
                @$tbody.append($tr)

        getUrl = (page) =>
            if not @url
                return '#'

            if not page?
                page = @page

            if not page or page == 1
                return @url
            else
                return @url + "?page=#{ page }"

        fillFooter = (total_pages) =>
            if not total_pages or total_pages == 1
                html = ''
            else
                html = "<tr><td class=\"paginator\" colspan=\"#{ @columns.length }\">"

                if not @current_page or @current_page == 1
                    html += '<span class="first disabled">first</span>'
                    html += '<span class="previous disabled">previous</span>'
                else
                    html += "<a href=\"#{ getUrl(1) }\" class=\"first\">first</a>"
                    html += "<a href=\"#{ getUrl(@current_page - 1) }\" class=\"previous\">previous</a>"

                html += "<span>page #{ @current_page } of #{ total_pages }</span>"

                if not @current_page or @current_page == total_pages
                    html += '<span class="next disabled">next</span>'
                    html += '<span class="last disabled">last</span>'
                else
                    html += "<a href=\"#{ getUrl(@current_page + 1) }\" class=\"next\">next</i></a>"
                    html += "<a href=\"#{ getUrl(total_pages) }\" class=\"last\">last</a>"

                html += "</td></tr>"

            @$tfoot.html(html)

        if $.isArray(data)
            rows = data
            total_pages = 0
        else if data.rows
            rows = data.rows
            total_pages = data.total_pages or 0
        else
            rows = []

        @total_pages = total_pages

        fillRows(rows)
        fillFooter(total_pages)

    _handleClickFirstPage: (e) ->
        @_gotoPage(1)
        return false

    _handleClickPreviousPage: (e) ->
        @_gotoPage(@current_page - 1)
        return false

    _handleClickNextPage: (e) ->
        @_gotoPage(@current_page + 1)
        return false

    _handleClickLastPage: (e) ->
        @_gotoPage(@total_pages)
        return false

    _gotoPage: (page) ->
        if page <= @total_pages
            @current_page = page
            @_loadData()
})
