# ============================================================================
# Proyecto Final de Bases de Datos
# Compila los fuentes de LaTeX/ y publica los PDF finales en Documentos/.
#
#   make            compila todo y actualiza Documentos/
#   make limpio     elimina temporales y PDF generados en LaTeX/
# ============================================================================

TEXDIR  := LaTeX
DESTDIR := Documentos
LATEXMK := latexmk
ENGINE  := -xelatex
AUXDIR  := .aux

LATEXMK_OPTS := $(ENGINE) -emulate-aux-dir -auxdir=$(AUXDIR) -interaction=nonstopmode

.PHONY: todo limpio planteamiento diagrama_er microservicios diccionario roles dimensiones
.DEFAULT_GOAL := todo

todo: planteamiento diagrama_er microservicios diccionario roles dimensiones
	@echo "Documentos actualizados en $(DESTDIR)/"

planteamiento:
	@echo "→ planteamiento"
	@cd $(TEXDIR) && $(LATEXMK) $(LATEXMK_OPTS) planteamiento.tex >/dev/null
	@mkdir -p $(DESTDIR)
	@cp $(TEXDIR)/planteamiento.pdf $(DESTDIR)/Planteamiento_y_diseno_BD.pdf

diagrama_er:
	@echo "→ diagrama_er"
	@cd $(TEXDIR) && $(LATEXMK) $(LATEXMK_OPTS) diagrama_er.tex >/dev/null
	@mkdir -p $(DESTDIR)/Diagramas
	@cp $(TEXDIR)/diagrama_er.pdf $(DESTDIR)/Diagramas/Diagrama_ER_proyecto_final_BD.pdf

microservicios:
	@echo "→ microservicios"
	@cd $(TEXDIR) && $(LATEXMK) $(LATEXMK_OPTS) microservicios.tex >/dev/null
	@mkdir -p $(DESTDIR)/Diagramas
	@cp $(TEXDIR)/microservicios.pdf $(DESTDIR)/Diagramas/Diagrama_de_microservicios_BD.pdf

diccionario:
	@echo "→ diccionario"
	@cd $(TEXDIR) && $(LATEXMK) $(LATEXMK_OPTS) diccionario.tex >/dev/null
	@mkdir -p $(DESTDIR)
	@cp $(TEXDIR)/diccionario.pdf $(DESTDIR)/Diccionario_de_datos_BD.pdf

roles:
	@echo "→ roles"
	@cd $(TEXDIR) && $(LATEXMK) $(LATEXMK_OPTS) roles.tex >/dev/null
	@mkdir -p $(DESTDIR)/Matrices
	@cp $(TEXDIR)/roles.pdf $(DESTDIR)/Matrices/Matriz_roles_BD.pdf

dimensiones:
	@echo "→ dimensiones"
	@cd $(TEXDIR) && $(LATEXMK) $(LATEXMK_OPTS) dimensiones.tex >/dev/null
	@mkdir -p $(DESTDIR)/Matrices
	@cp $(TEXDIR)/dimensiones.pdf $(DESTDIR)/Matrices/Modificacion_de_datos_BD.pdf

limpio:
	@rm -rf $(TEXDIR)/$(AUXDIR) $(TEXDIR)/*.pdf $(TEXDIR)/*.aux \
		$(TEXDIR)/*.log $(TEXDIR)/*.out $(TEXDIR)/*.toc \
		$(TEXDIR)/*.fls $(TEXDIR)/*.fdb_latexmk
	@echo "Temporales eliminados"
