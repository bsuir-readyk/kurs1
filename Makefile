name = "sqlrc"


default: bnr;


build:
	@fpc ${name}$$N.dpr -obin_${name}$$N -ap -CO -Mdelphi -Un

run:
	@./bin_${name}$$N
	
bnr:
	@echo "\n\n---===---\nbuilding... \n---===---\n\n"
	
	@set +e; \
	make build; \
	EXIT_CODE=$$?; \
	make clean; \
	exit $$EXIT_CODE;

	@echo "\n\n---===---\nbuild done \ntrying to run:\n---===---\n\n"
	@make run

clean:
	@set +e;\
	rm -rv ./ppaslink.sh;\
	rm -rv ./symbol_order.fpc;\
	rm -rv ./link*.res;\
	rm -rvI ./*.ppu ./*/*.ppu ./*/*/*.ppu ./*/*/*/*.ppu;\
	rm -rvI ./*.o ./*/*.o ./*/*/*.o ./*/*/*/*.o; \
	exit 0;
