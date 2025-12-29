from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from jinja2 import Template
from dataclasses import dataclass


TEMPLATES_DIR = Path(__file__).parent / 'templates'
COMBINED_TEMPLATE_PATH = TEMPLATES_DIR / 'index.html'


@dataclass
class ResultSummary:
    header_text: str
    regions_info: str
    query_title: str
    table_rows: list[dict]


@dataclass
class ResultDetail:
    query: str
    region: int | str
    hits: list[dict]


def parse_summary(path: Path) -> tuple[str, list[dict]]:
    """
    Parse PHASTEST summary table output.

    Extracts the header text and the space-delimited table from the body
    into a list of dictionaries representing rows. Splits composite columns
    like COMPLETENESS(score) into separate columns.

    Args:
        path: Path to the PHASTEST summary table text file

    Returns:
        Tuple of (header_text, table_rows) where header_text is the
        documentation header and table_rows is a list of dictionaries
        with column names as keys
    """
    with open(path, 'r') as f:
        lines = f.readlines()

    # Find the header line (contains column names like REGION, REGION_LENGTH)
    header_idx = None
    for i, line in enumerate(lines):
        if 'regions have been identified.' in line:
            regions_info = line.strip()
        elif 'REGION' in line and 'REGION_LENGTH' in line:
            header_idx = i
            break

    if header_idx is None:
        return "", []

    # Extract result metadata (everything before the table)
    header_text = ''.join(lines[:header_idx]).strip()
    query_title = lines[header_idx - 1].strip()
    header_line = lines[header_idx].strip()
    headers = header_line.split()

    results = []

    # Parse data rows starting after the separator line
    # (skip header line and the dashed separator line)
    for line in lines[header_idx + 2:]:
        line = line.strip()
        if not line:
            continue

        # Split by whitespace, limiting to the number of expected columns
        values = line.split(None, len(headers) - 1)

        if len(values) == len(headers):
            row_dict = dict(zip(headers, values))
            row_dict = _split_composite_columns(row_dict)
            results.append(row_dict)

    return ResultSummary(
        header_text=header_text,
        regions_info=regions_info,
        query_title=query_title,
        table_rows=results
    )


def _split_composite_columns(row_dict: dict) -> dict:
    """
    Split composite columns like COMPLETENESS(score) into separate columns.

    Args:
        row_dict: Dictionary with composite column values

    Returns:
        Dictionary with split columns
    """
    result = {}

    for key, value in row_dict.items():
        # Handle COMPLETENESS(score)
        if key == 'COMPLETENESS(score)':
            if '(' in value and ')' in value:
                completeness = value.split('(')[0]
                score = value.split('(')[1].rstrip(')')
                result['COMPLETENESS'] = completeness
                result['score'] = score
            else:
                result['COMPLETENESS'] = value
                result['score'] = ''

        # Handle MOST_COMMON_PHAGE_NAME(hit_genes_count)
        elif key == 'MOST_COMMON_PHAGE_NAME(hit_genes_count)':
            # Parse the comma-separated list of phage entries
            phage_names = []
            hit_counts = []

            # Split by comma, but be careful with entries like:
            # PHAGE_Name(7),PHAGE_Other(6)
            entries = value.split(',')
            for entry in entries:
                entry = entry.strip()
                if '(' in entry and ')' in entry:
                    name = entry.split('(')[0]
                    count = entry.split('(')[1].rstrip(')')
                    phage_names.append(name)
                    hit_counts.append(count)

            result['MOST_COMMON_PHAGE_NAME'] = ','.join(phage_names)
            result['hit_genes_count'] = ','.join(hit_counts)

        else:
            result[key] = value

    return result


def calculate_bs_class(completeness: str) -> str:
    """Calculate bootstrap class based on completeness."""
    _map = {
        'intact': 'success',
        'questionable': 'warning',
        'incomplete': 'danger'
    }
    return _map.get(completeness, '')


def parse_detail(path: Path) -> list[ResultDetail]:
    """
    Parse PHASTEST detail table output.

    Extracts the detail table with CDS information, organized by query
    sequence and region.

    Args:
        path: Path to the PHASTEST detail table text file

    Returns:
        List of ResultDetail objects with query, region, and hits data
    """
    with open(path, 'r') as f:
        lines = f.readlines()

    # Find the header line (contains column names like CDS_POSITION)
    header_idx = None
    for i, line in enumerate(lines):
        if 'CDS_POSITION' in line and 'BLAST_HIT' in line:
            header_idx = i
            break

    if header_idx is None:
        return []

    # Extract column headers (split by double space to preserve spaces
    # within column names)
    header_line = lines[header_idx].strip()
    # Split on multiple spaces (2+) to get column boundaries
    headers = [h.strip() for h in re.split(r'  +', header_line)]

    # Find query sequence info (first non-empty line before header)
    query_info = None
    for i in range(header_idx - 1, -1, -1):
        if lines[i].strip():
            query_info = lines[i].strip()
            break

    results = []
    current_region = None
    current_hits = []

    # Parse data rows starting after the separator line
    for line in lines[header_idx + 2:]:
        line_stripped = line.strip()

        # Track region markers
        if line_stripped.startswith('#### region'):
            region_num = line_stripped.split()[2]
            # Save previous region if exists
            if current_region is not None:
                results.append(ResultDetail(
                    query=query_info if query_info else 'Unknown',
                    region=int(current_region) if current_region.isdigit() else current_region,
                    hits=current_hits
                ))
            # Start new region
            current_region = region_num
            current_hits = []
            continue
        elif line_stripped.startswith('####'):
            # End of regions - save last region
            if current_region is not None:
                results.append(ResultDetail(
                    query=query_info if query_info else 'Unknown',
                    region=(
                        int(current_region)
                        if current_region.isdigit()
                        else current_region
                    ),
                    hits=current_hits
                ))
                current_hits = []
            current_region = None
            continue

        if not line_stripped or line_stripped.startswith('---'):
            continue

        # Skip if not in a region
        if current_region is None:
            continue

        # Split by multiple spaces (2+) to preserve spaces within values
        values = [v.strip() for v in re.split(r'  +', line_stripped)]

        if len(values) == len(headers):
            row_dict = dict(zip(headers, values))
            row_dict['prophage_PRO_SEQ'] = _wrap_seq(
                row_dict.get('prophage_PRO_SEQ', ''))
            current_hits.append(row_dict)

    # Don't forget to add the last region
    if current_region is not None:
        results.append(ResultDetail(
            query=query_info if query_info else 'Unknown',
            region=int(current_region) if current_region.isdigit() else current_region,
            hits=current_hits
        ))

    return results


def _wrap_seq(seq: str, line_length: int = 80) -> str:
    return '\n'.join(
        seq[i:i+line_length]
        for i in range(0, len(seq), line_length)
    )


def render_combined_html(
    result_summary: ResultSummary,
    detail_data: list[ResultDetail],
    output_path: Path = None,
) -> str:
    """
    Render PHASTEST summary and detail data as tabbed HTML.

    Args:
        result_summary: ResultSummary object with header and table data
        detail_data: List of ResultDetail objects with query, region, and hits
        output_path: Optional path to write HTML output

    Returns:
        Rendered HTML string
    """
    with open(COMBINED_TEMPLATE_PATH, 'r') as f:
        template_str = f.read()

    template = Template(template_str)
    html = template.render(
        result_summary=result_summary,
        detail_data=detail_data,
        calculate_bs_class=calculate_bs_class,
    )

    if output_path:
        with open(output_path, 'w') as f:
            f.write(html)

    return html


def main():
    """
    Main CLI entry point for parsing PHASTEST outputs and generating HTML.
    """
    parser = argparse.ArgumentParser(
        description='Parse PHASTEST summary and detail tables, '
                    'and generate combined HTML report'
    )
    parser.add_argument(
        'path',
        type=Path,
        help='Path to the directory containing summary.txt and detail.txt'
             ' files',
    )
    parser.add_argument(
        '--output',
        type=Path,
        default='report.html',
        help='Output path for the HTML file (default: report.html)'
    )

    args = parser.parse_args()

    summary_path = args.path / 'summary.txt'
    detail_path = args.path / 'detail.txt'

    if not summary_path.exists():
        print(f"Error: Summary file not found: {summary_path}",
              file=sys.stderr)
        sys.exit(1)

    if not detail_path.exists():
        print(f"Error: Detail file not found: {detail_path}", file=sys.stderr)
        sys.exit(1)

    try:
        result_summary = parse_summary(summary_path)
        detail_data = parse_detail(detail_path)
    except Exception as e:
        msg = f"Error parsing input files: {e}"
        print(msg, file=sys.stderr)
        args.output.write_text(msg)
        return

    try:
        render_combined_html(
            result_summary,
            detail_data,
            output_path=args.output
        )
    except Exception as e:
        msg = f"Error rendering HTML: {e}"
        print(msg, file=sys.stderr)
        args.output.write_text(msg)
        return

    print(f"HTML report generated: {args.output}", file=sys.stderr)


if __name__ == '__main__':
    main()
