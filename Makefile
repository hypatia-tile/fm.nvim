NVIM ?= nvim

# Each spec quits on success; a failing assertion exits with status 1.
.PHONY: test
test:
	@for spec in tests/*_spec.lua; do \
		$(NVIM) --headless -u NONE -c "set rtp+=." \
			-c "lua local ok, err = pcall(dofile, '$$spec'); if not ok then io.stderr:write(err, '\n'); vim.cmd('cquit 1') end" \
			|| exit 1; \
		echo; \
	done
