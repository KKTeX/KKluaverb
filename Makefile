# ----- setting ------
SAMPLE_TARGET = kkluaverb-sample
TEST1_TARGET = kkluaverb-test1
TEST2_TARGET = kkluaverb-test2
DOC_TARGET = kkluaverb-doc
RC     = .latexmkrc


# ----- main ------
.PHONY: 
	clean distclean pvc zip doc 
	test1 test2 smaple

# compile
doc:
	latexmk -r $(RC) $(DOC_TARGET).tex
	$(MAKE) clean

sample:
	latexmk -r $(RC) $(SAMPLE_TARGET).tex
	$(MAKE) clean

test1:
# 	$(MAKE) distclean
	latexmk -r $(RC) $(TEST1_TARGET).tex
	$(MAKE) clean

test2:
# 	$(MAKE) distclean
	latexmk -r $(RC) $(TEST2_TARGET).tex
	$(MAKE) clean

# cleaning except for PDF
clean:
	latexmk -c

# cleaning including PDF
distclean:
	latexmk -C

# compile on save
# pvc:
# 	latexmk -pvc -r $(RC) $(TARGET).tex

# ----- CTAN setting -----
PACKAGE = kkluaverb
styFILENAME = KKluaverb
ZIP_DIR = $(PACKAGE)

# ----- zip generation -----
zip: distclean builddoc
	mkdir -p $(ZIP_DIR)
	cp $(styFILENAME).lua $(ZIP_DIR)
	cp $(styFILENAME).sty $(ZIP_DIR)
	cp README.md $(ZIP_DIR)
	cp LICENSE.md $(ZIP_DIR)
	cp $(PACKAGE)-doc.tex $(ZIP_DIR)
	cp $(PACKAGE)-doc.pdf $(ZIP_DIR)
	zip -r $(PACKAGE).zip $(ZIP_DIR) -x "*/.*" "*~"
	rm -rf $(ZIP_DIR)