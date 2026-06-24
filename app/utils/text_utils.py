import re


def build_snippet(page_text: str, query: str, window: int = 150) -> str:
    """
    Extract a context window around the first match and wrap every
    matched word in <mark>...</mark> for frontend highlighting.
    """
    words = _extract_words(query)
    if not words:
        return page_text[:window * 2].strip() + "..."

    first_pattern = re.compile(re.escape(words[0]), re.IGNORECASE)
    match = first_pattern.search(page_text)

    if match:
        start = max(0, match.start() - window)
        end = min(len(page_text), match.end() + window)
        excerpt = (("..." if start > 0 else "") +
                   page_text[start:end].strip() +
                   ("..." if end < len(page_text) else ""))
    else:
        excerpt = page_text[:window * 2].strip() + "..."

    for word in words:
        excerpt = re.compile(re.escape(word), re.IGNORECASE).sub(
            lambda m: f"<mark>{m.group()}</mark>", excerpt
        )

    return excerpt


def prepare_fts_query(query: str) -> str:
    """
    Wrap a plain multi-word query in double quotes so SQL Server treats
    it as a phrase search.  If the caller already uses FTS operators
    (AND, OR, NEAR, *) it is passed through unchanged.
    """
    query = query.strip()
    fts_operators = re.compile(r'\b(AND|OR|NOT|NEAR|FORMSOF|INFLECTIONAL)\b|\*|"', re.IGNORECASE)
    if fts_operators.search(query):
        return query
    if " " in query:
        return f'"{query}"'
    return query


def _extract_words(query: str) -> list[str]:
    """Strip FTS operators and return plain words for snippet highlighting."""
    cleaned = re.sub(r'\b(AND|OR|NOT|NEAR|FORMSOF|INFLECTIONAL|THESAURUS)\b', ' ', query, flags=re.IGNORECASE)
    cleaned = re.sub(r'["\*]', ' ', cleaned)
    return [w.strip() for w in cleaned.split() if len(w.strip()) > 1]
