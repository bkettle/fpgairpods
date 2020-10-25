\LoadClass{article}
\ProvidesClass{fpgairpods}[2020/10/25 6.111 Team 25 Document Template]

\RequirePackage[explicit]{titlesec}
\RequirePackage{enumitem}
\RequirePackage{times}
\RequirePackage{helvet}
\RequirePackage{courier}
\RequirePackage{color}
\RequirePackage{multicol}
\RequirePackage{lipsum}
\RequirePackage{listings}
\RequirePackage{graphicx}
\RequirePackage{fancyhdr}
\RequirePackage[%  
    colorlinks=true,
    pdfborder={0 0 0},
    linkcolor=blue
]{hyperref}
\RequirePackage[all]{hypcap}
\RequirePackage{float}
\RequirePackage{textcomp}
\RequirePackage{placeins}
\RequirePackage[%
  autocite    = superscript,
  backend     = bibtex,
  sortcites   = true,
  style       = numeric,
]{biblatex}

\titleformat{\section}
  {\normalfont\fontsize{12}{15}\bfseries}{\thesection \quad \MakeUppercase{#1}}{1em}{}
\titleformat{\subsection}
  {\normalfont\fontsize{10}{12}\bfseries}{\thesubsection \quad \MakeUppercase{#1}}{1em}{}
\titleformat{\subsubsection}
  {\normalfont\fontsize{10}{12}\bfseries}{#1}{1em}{}
\titlespacing{\section}{0pt}{10pt}{6pt}
\titlespacing{\subsection}{0pt}{10pt}{0pt}
\titlespacing{\subsubsection}{0pt}{4pt}{0pt}
