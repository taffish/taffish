(in-package :taf.core)

;;;; Conservative terminal columns, independent of the selected UI language.
;;;; This is a supported subset, not a Unicode grapheme/terminal emulator.
;;;
;;; Generated data: Unicode 15.1.0, https://www.unicode.org/Public/15.1.0/ucd/
;;; SHA-256 (filenames relative to that directory):
;;; EastAsianWidth.txt
;;;   b08191401dc125f4e84ef262a95754faae6b737c79538e17ea9664a63434e94e
;;; UnicodeData.txt
;;;   2fc713e6a31a87c4850a37fe2caffa4218180fadb5de86b43a143ddb4581fb86
;;; DerivedCoreProperties.txt
;;;   f55d0db69123431a7317868725b1fcbf1eab6b265d756d1bd7f0f6d9f9ee108b
;;; emoji/emoji-data.txt
;;;   d7aef489c8fe4c14f09ea5695200277c6b93ac82ac60845cdd2161b0d6835cc1
;;;
;;; Generation recipe (inclusive code-point ranges, merged and sorted):
;;; Expand UnicodeData First/Last records. Except ASCII U+0020..007E, exclude
;;; Default_Ignorable_Code_Point, Emoji, Emoji_Component, Extended_Pictographic.
;;; ZERO: category Mn in 0300..036F, 1AB0..1AFF, 1DC0..1DFF, 20D0..20FF,
;;;       3099..309A, FE20..FE2F. A preceding supported base is also required.
;;; NARROW: ASCII plus categories L/N/P/S/Zs with EAW N/Na/H in 00A0..02FF,
;;;         1E00..1EFF, FF61..FF9D.
;;; WIDE: assigned categories L/N/P/S/Zs with EAW W/F, excluding conjoining
;;;       Hangul Jamo 1100..11FF, A960..A97F, D7B0..D7FF.
;;; Everything else (including ambiguous EAW A, shaping scripts, unassigned
;;; characters, controls, selectors and emoji sequences) is unknown, not zero.
;;; No Unicode downloads, normalization or host-specific tables at runtime.

;;; Unicode data copyright (c) 1991-2023 Unicode, Inc.
;;; UNICODE LICENSE V3
;;;
;;; COPYRIGHT AND PERMISSION NOTICE
;;;
;;; Copyright (c) 1991-2026 Unicode, Inc.
;;;
;;; NOTICE TO USER: Carefully read the following legal agreement. BY
;;; DOWNLOADING, INSTALLING, COPYING OR OTHERWISE USING DATA FILES, AND/OR
;;; SOFTWARE, YOU UNEQUIVOCALLY ACCEPT, AND AGREE TO BE BOUND BY, ALL OF THE
;;; TERMS AND CONDITIONS OF THIS AGREEMENT. IF YOU DO NOT AGREE, DO NOT
;;; DOWNLOAD, INSTALL, COPY, DISTRIBUTE OR USE THE DATA FILES OR SOFTWARE.
;;;
;;; Permission is hereby granted, free of charge, to any person obtaining a
;;; copy of data files and any associated documentation (the "Data Files") or
;;; software and any associated documentation (the "Software") to deal in the
;;; Data Files or Software without restriction, including without limitation
;;; the rights to use, copy, modify, merge, publish, distribute, and/or sell
;;; copies of the Data Files or Software, and to permit persons to whom the
;;; Data Files or Software are furnished to do so, provided that either (a)
;;; this copyright and permission notice appear with all copies of the Data
;;; Files or Software, or (b) this copyright and permission notice appear in
;;; associated Documentation.
;;;
;;; THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
;;; KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF
;;; THIRD PARTY RIGHTS.
;;;
;;; IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN THIS NOTICE
;;; BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR CONSEQUENTIAL DAMAGES,
;;; OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
;;; WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
;;; ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THE DATA
;;; FILES OR SOFTWARE.
;;;
;;; Except as contained in this notice, the name of a copyright holder shall
;;; not be used in advertising or otherwise to promote the sale, use or other
;;; dealings in these Data Files or Software without prior written
;;; authorization of the copyright holder.

(defparameter *display-zero-ranges*
  #(
    #x300 #x34E  #x350 #x36F  #x1AB0 #x1ABD  #x1ABF #x1ACE
    #x1DC0 #x1DFF  #x20D0 #x20DC  #x20E1 #x20E1  #x20E5 #x20F0
    #x3099 #x309A  #xFE20 #xFE2F
    ))

(defparameter *display-narrow-ranges*
  #(
    #x20 #x7E  #xA0 #xA0  #xA2 #xA3  #xA5 #xA6
    #xAB #xAC  #xAF #xAF  #xB5 #xB5  #xBB #xBB
    #xC0 #xC5  #xC7 #xCF  #xD1 #xD6  #xD9 #xDD
    #xE2 #xE5  #xE7 #xE7  #xEB #xEB  #xEE #xEF
    #xF1 #xF1  #xF4 #xF6  #xFB #xFB  #xFD #xFD
    #xFF #x100  #x102 #x110  #x112 #x112  #x114 #x11A
    #x11C #x125  #x128 #x12A  #x12C #x130  #x134 #x137
    #x139 #x13E  #x143 #x143  #x145 #x147  #x14C #x14C
    #x14E #x151  #x154 #x165  #x168 #x16A  #x16C #x1CD
    #x1CF #x1CF  #x1D1 #x1D1  #x1D3 #x1D3  #x1D5 #x1D5
    #x1D7 #x1D7  #x1D9 #x1D9  #x1DB #x1DB  #x1DD #x250
    #x252 #x260  #x262 #x2C3  #x2C5 #x2C6  #x2C8 #x2C8
    #x2CC #x2CC  #x2CE #x2CF  #x2D1 #x2D7  #x2DC #x2DC
    #x2DE #x2DE  #x2E0 #x2FF  #x1E00 #x1EFF  #xFF61 #xFF9D
    ))

(defparameter *display-wide-ranges*
  #(
    #x2329 #x232A  #x2E80 #x2E99  #x2E9B #x2EF3  #x2F00 #x2FD5
    #x2FF0 #x3029  #x3031 #x303C  #x303E #x303E  #x3041 #x3096
    #x309B #x30FF  #x3105 #x312F  #x3131 #x3163  #x3165 #x318E
    #x3190 #x31E3  #x31EF #x321E  #x3220 #x3247  #x3250 #x3296
    #x3298 #x3298  #x329A #x4DBF  #x4E00 #xA48C  #xA490 #xA4C6
    #xAC00 #xD7A3  #xF900 #xFA6D  #xFA70 #xFAD9  #xFE10 #xFE19
    #xFE30 #xFE52  #xFE54 #xFE66  #xFE68 #xFE6B  #xFF01 #xFF60
    #xFFE0 #xFFE6  #x16FE0 #x16FE3  #x17000 #x187F7  #x18800 #x18CD5
    #x18D00 #x18D08  #x1AFF0 #x1AFF3  #x1AFF5 #x1AFFB  #x1AFFD #x1AFFE
    #x1B000 #x1B122  #x1B132 #x1B132  #x1B150 #x1B152  #x1B155 #x1B155
    #x1B164 #x1B167  #x1B170 #x1B2FB  #x1F200 #x1F200  #x1F210 #x1F219
    #x1F21B #x1F22E  #x1F230 #x1F231  #x1F23B #x1F23B  #x1F240 #x1F248
    #x20000 #x2A6DF  #x2A700 #x2B739  #x2B740 #x2B81D  #x2B820 #x2CEA1
    #x2CEB0 #x2EBE0  #x2EBF0 #x2EE5D  #x2F800 #x2FA1D  #x30000 #x3134A
    #x31350 #x323AF
    ))

(defun %display-code-in-ranges-p (code ranges)
  (loop with low = 0
        with high = (1- (/ (length ranges) 2))
        while (<= low high)
        for middle = (floor (+ low high) 2)
        for index = (* middle 2)
        do (cond ((< code (aref ranges index))
                  (setf high (1- middle)))
                 ((> code (aref ranges (1+ index)))
                  (setf low (1+ middle)))
                 (t (return t)))))

(defun %display-width (text)
  "Return supported terminal columns for string TEXT, or NIL when uncertain.
Combining marks need a preceding non-space supported base. Newlines, tabs,
controls, ambiguous widths and complex glyphs require a non-aligned layout."
  (check-type text string)
  (loop with width = 0
        with base-p = nil
        for character across text
        for code = (char-code character)
        do (cond
             ((%display-code-in-ranges-p code *display-zero-ranges*)
              (unless base-p (return-from %display-width nil)))
             ((%display-code-in-ranges-p code *display-narrow-ranges*)
              (incf width)
              (setf base-p (not (member code '(#x20 #xA0)))))
             ((%display-code-in-ranges-p code *display-wide-ranges*)
              (incf width 2)
              (setf base-p (/= code #x3000)))
             (t (return-from %display-width nil)))
        finally (return width)))

(defun %display-write-lines (text indentation stream &optional suffix)
  ;; Preserve every input line (including empty/trailing lines) without wrapping.
  (loop for start = 0 then (1+ end)
        for end = (position #\Newline text :start start)
        do (write-string indentation stream)
           (write-string text stream :start start :end end)
           (when (and suffix (null end)) (write-string suffix stream))
           (terpri stream)
        while end))

(defun %print-display-fields (rows &key (stream *standard-output*) (min-label-width 0))
  "Print ROWS of (label value) strings to STREAM, returning NIL.
Known labels of at most 24 columns share dynamic padding before the colon.
MIN-LABEL-WIDTH provides a common minimum for separate calls (e.g. 15 for info).
Rows exceeding an 80-column layout budget, longer labels, multiline or unknown-width text use
separate label/value lines. The budget is not a terminal-width query. Values
are never truncated or wrapped; continuation lines are indented. No escaping,
language selection, terminal control sequences or stream probing is performed."
  (check-type min-label-width (integer 0 *))
  (let* ((measured
           (mapcar (lambda (row)
                     (destructuring-bind (label value) row
                       (list label value (%display-width label)
                             (%display-width value))))
                   rows))
         (padding-width
           (max min-label-width
                (loop for row in measured
                      for width = (third row)
                      when (and width (<= width 24)) maximize width into maximum
                      finally (return (or maximum 0))))))
    (dolist (row measured)
      (destructuring-bind (label value label-width value-width) row
        (if (and label-width value-width (<= label-width 24) (<= padding-width 24)
                 (<= (+ padding-width value-width 5) 80))
            (progn
              (write-string "  " stream)
              (write-string label stream)
              (write-string (make-string (1+ (- padding-width label-width))
                                         :initial-element #\Space)
                            stream)
              (write-string ": " stream)
              (write-string value stream)
              (terpri stream))
            (progn
              (%display-write-lines label "  " stream ":")
              (%display-write-lines value "    " stream))))))
  nil)
