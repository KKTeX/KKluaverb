# ----- setting ------
SAMPLE_TARGET = kkluaverb-sample
TEST1_TARGET = kkluaverb-test1
DOC_TARGET = kkluaverb-doc
RC     = .latexmkrc


# ----- main ------
.PHONY: clean distclean pvc zip builddoc buildtest

# compile
builddoc:
	latexmk -r $(RC) $(DOC_TARGET).tex
	$(MAKE) clean

buildsample:
	latexmk -r $(RC) $(SAMPLE_TARGET).tex
	$(MAKE) clean

buildtest1:
# 	$(MAKE) distclean
	latexmk -r $(RC) $(TEST1_TARGET).tex
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