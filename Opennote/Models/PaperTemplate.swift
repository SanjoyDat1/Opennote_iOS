import Foundation

/// Default LaTeX template for new papers - Opennote Papers guide.
enum PaperTemplate {
    static let defaultContent = """
\\documentclass{article}
\\usepackage[utf8]{inputenc}
\\usepackage{amsmath, amssymb, amsthm}
\\usepackage{graphicx}
\\usepackage{hyperref}
\\usepackage{xcolor}
\\usepackage{listings}
\\usepackage{geometry}

\\geometry{margin=1in}

\\definecolor{opennoteblue}{RGB}{59, 130, 246}
\\definecolor{codegreen}{RGB}{34, 197, 94}
\\definecolor{codegray}{RGB}{107, 114, 128}

\\hypersetup{
    colorlinks=true,
    linkcolor=opennoteblue,
    urlcolor=opennoteblue
}

\\title{\\textbf{Welcome to Papers} \\\\ \\large A Guide to Opennote's \\LaTeX{} Editor}
\\author{The Opennote Team}
\\date{\\today}

\\begin{document}

\\maketitle

\\begin{abstract}
Papers is Opennote's collaborative \\LaTeX{} editor, designed to make academic writing seamless and productive. This document serves as both a tutorial for the editor's features and a template for your own documents.
\\end{abstract}

\\tableofcontents
\\newpage

%==============================================================================
\\section{Getting Started with Papers}
%==============================================================================

Welcome to \\textbf{Papers}, the integrated \\LaTeX{} editing environment built into Opennote. Whether you're writing research papers, thesis chapters, problem sets, or technical documentation, Papers provides everything you need in one place.

\\subsection{The Editor Interface}

The Papers editor consists of two main panels:

\\begin{itemize}
    \\item \\textbf{Left Panel:} The \\LaTeX{} source editor where you write your code
    \\item \\textbf{Right Panel:} The live PDF preview of your compiled document
\\end{itemize}

You can resize these panels by dragging the divider between them to customize your workspace.

%==============================================================================
\\section{Writing \\LaTeX{} in Papers}
%==============================================================================

Here's a quick refresher on common \\LaTeX{} patterns you can use in Papers.

\\subsection{Mathematical Expressions}

Inline math uses single dollar signs: $E = mc^2$.

Display math uses the equation environment:

\\begin{equation}
    \\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}
\\end{equation}

\\subsection{Lists}

\\textbf{Itemized lists:}
\\begin{itemize}
    \\item First item
    \\item Second item
\\end{itemize}

\\textbf{Enumerated lists:}
\\begin{enumerate}
    \\item Step one
    \\item Step two
\\end{enumerate}

\\vspace{1em}
\\begin{center}
\\textit{Happy writing from the Opennote team!}
\\end{center}

\\end{document}
"""
}
