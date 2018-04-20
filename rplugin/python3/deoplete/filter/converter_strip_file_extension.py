# ============================================================================
# FILE: converter_auto_paren.py
# AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
# License: MIT license
# ============================================================================

import re
import os
from .base import Base


class Filter(Base):
    def __init__(self, vim):
        super().__init__(vim)

        self.name = 'converter_strip_file_extension'
        self.description = 'remove file extension from file completion'

    def filter(self, context):
        p = re.compile('\..*$')
        for candidate in [x for x in context['candidates']
                          if p.search(x['word'])]:
            [fname, ext] = os.path.splitext(candidate['word'])
            if ext:
                candidate['word'] = re.sub(
                    '\\' + ext + '$', '', candidate['word'])
                candidate['menu'] = '[' + ext[1:] + ']'
        return context['candidates']
