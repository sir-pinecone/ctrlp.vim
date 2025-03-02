" =============================================================================
" File:          autoload/ctrlp/tag.vim
" Description:   Tag file extension
" Author:        Kien Nguyen <github.com/kien>
" =============================================================================

" Init {{{1
if exists('g:loaded_ctrlp_tag') && g:loaded_ctrlp_tag
	fini
en
let g:loaded_ctrlp_tag = 1

cal add(g:ctrlp_ext_vars, {
	\ 'init': 'ctrlp#tag#init()',
	\ 'accept': 'ctrlp#tag#accept',
	\ 'lname': 'tags',
	\ 'sname': 'tag',
	\ 'enter': 'ctrlp#tag#enter()',
	\ 'type': 'tabs',
	\ })

let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)

" Utilities {{{1
fu! s:findcount(str, tgaddr)
	let [tg, ofname] = split(a:str, '\t\+\ze[^\t]\+$')
	let tgs = taglist('^'.tg.'$')
	if len(tgs) < 2
		retu [0, 0, 0, 0]
	en
	let bname = fnamemodify(bufname('%'), ':p')
	let fname = expand(fnamemodify(simplify(ofname), ':s?^[.\/]\+??:p:.'), 1)
	let [fnd, cnt, pos, ctgs, otgs] = [0, 0, 0, [], []]
	for tgi in tgs
		let lst = bname == fnamemodify(tgi["filename"], ':p') ? 'ctgs' : 'otgs'
		cal call('add', [{lst}, tgi])
	endfo
	let ntgs = ctgs + otgs
	for tgi in ntgs
		let cnt += 1
		let fulname = fnamemodify(tgi["filename"], ':p')
		if stridx(fulname, fname) >= 0
			\ && strlen(fname) + stridx(fulname, fname) == strlen(fulname)
			let fnd += 1
			let pos = cnt
		en
	endfo
	let cnt = 0
	for tgi in ntgs
		let cnt += 1
		if tgi["filename"] == ofname
			if a:tgaddr != ""
				if a:tgaddr == tgi["cmd"]
					let [fnd, pos] = [0, cnt]
				en
			else
				let [fnd, pos] = [0, cnt]
			en
		en
	endfo
	retu [1, fnd, pos, len(ctgs)]
endf

fu! s:filter(tags)
	let nr = 0
	wh 0 < 1
		if a:tags == [] | brea | en
		if a:tags[nr] =~ '^!' && a:tags[nr] !~# '^!_TAG_'
			let nr += 1
			con
		en
		if a:tags[nr] =~# '^!_TAG_' && len(a:tags) > nr
			cal remove(a:tags, nr)
		el
			brea
		en
	endw
	retu a:tags
endf

fu! s:syntax()
	if !ctrlp#nosy()
		cal ctrlp#hicheck('CtrlPTabExtra', 'Comment')
		sy match CtrlPTabExtra '\zs\t.*\ze$'
	en
endf

" Public {{{1
fu! ctrlp#tag#init()
	if empty(s:tagfiles) | retu [] | en
	let g:ctrlp_alltags = []

    " @campo Filter out duplicate tags, which I get when searching multiple
    " tag files, i.e. jai root tags + project tags.
    " I wrote four different approaches and they're all slow. None really
    " stand out so I'll just pick one for now and can tweak later if need be.

    " Dedupe method 1 and 2
    "let seen = {}

	let tagfiles = sort(filter(s:tagfiles, 'count(s:tagfiles, v:val) == 1'))
	for each in tagfiles
		let alltags = s:filter(ctrlp#utils#readfile(each))

        " Dedupe method 1
        "let deduped = filter(alltags, '!has_key(seen, v:val)')
        "for tag in deduped
        "    let seen[tag] = 1
        "endfor
		"cal extend(g:ctrlp_alltags, deduped)

        " Dedupe method 2
        "let filtered_tags = []
        "for tag in alltags
        "    if !has_key(seen, tag)
        "        call add(filtered_tags, tag)
        "        let seen[tag] = 1
        "    endif
        "endfor
		"cal extend(g:ctrlp_alltags, filtered_tags)

        " Dedupe method 3 and 4
		cal extend(g:ctrlp_alltags, alltags)
	endfo

    " Dedupe method 3
    "fu! RemoveDuplicateTags(alltags)
    "    let seen = {}
    "    let unique_list = []
    "    for tag in a:alltags
    "        if !has_key(seen, tag)
    "            call add(unique_list, tag)
    "            let seen[tag] = 1
    "        endif
    "    endfor
    "    return unique_list
    "endfu
    "let g:ctrlp_alltags = RemoveDuplicateTags(g:ctrlp_alltags)

    " Dedupe method 4
    fu! CompareByValue(tag1, tag2)
        return a:tag1 == a:tag2 ? 0 : -1
    endfu
    call sort(g:ctrlp_alltags)
    call uniq(g:ctrlp_alltags, 'CompareByValue')

	cal s:syntax()
	retu g:ctrlp_alltags
endf

fu! ctrlp#tag#accept(mode, str)
	cal ctrlp#exit()
	let tgaddr = matchstr(a:str, '^[^\t]\+\t\+[^\t]\+\t\zs[^\t]\{-1,}\ze\%(;"\)\?\t')
	let str = matchstr(a:str, '^[^\t]\+\t\+[^\t]\+\ze\t')
	let [tg, fdcnt] = [split(str, '^[^\t]\+\zs\t')[0], s:findcount(str, tgaddr)]
	let cmds = {
		\ 't': ['tab sp', 'tab stj'],
		\ 'h': ['sp', 'stj'],
		\ 'v': ['vs', 'vert stj'],
		\ 'e': ['', 'tj'],
		\ }
	let utg = fdcnt[3] < 2 && fdcnt[0] == 1 && fdcnt[1] == 1
	let cmd = !fdcnt[0] || utg ? cmds[a:mode][0] : cmds[a:mode][1]
	let cmd = a:mode == 'e' && ctrlp#modfilecond(!&aw)
		\ ? ( cmd == 'tj' ? 'stj' : 'sp' ) : cmd
	let cmd = a:mode == 't' ? ctrlp#tabcount().cmd : cmd
	if !fdcnt[0] || utg
		if cmd != ''
			exe cmd
		en
		if exists('&cst')
			let save_cst = &cst
			set cst&
		en
		cal feedkeys(":".( utg ? fdcnt[2] : "" )."ta ".tg."\r", 'nt')
		if exists('&cst')
			let &cst = save_cst
		en
	el
		let ext = ""
		if fdcnt[1] < 2 && fdcnt[2]
			let [sav_more, &more] = [&more, 0]
			let ext = fdcnt[2]."\r".":let &more = ".sav_more."\r"
		en
		cal feedkeys(":".cmd." ".tg."\r".ext, 'nt')
	en
	cal feedkeys('zvzz', 'nt')
	cal ctrlp#setlcdir()
endf

fu! ctrlp#tag#id()
	retu s:id
endf

fu! ctrlp#tag#enter()
	let tfs = get(g:, 'ctrlp_custom_tag_files', tagfiles())
	let s:tagfiles = type(tfs) == 3 && tfs != [] ? filter(map(tfs, 'fnamemodify(v:val, ":p")'),
		\ 'filereadable(v:val)') : []
endf
"}}}

