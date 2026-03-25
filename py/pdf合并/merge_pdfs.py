#!/usr/bin/env python3
"""
PDF 合并工具
将两个指定的 PDF 文件拼接成一个输出文件

用法:
    python merge_pdfs.py <pdf1> <pdf2> [输出文件名]

示例:
    python merge_pdfs.py file1.pdf file2.pdf
    python merge_pdfs.py file1.pdf file2.pdf merged_output.pdf
"""

import sys
import os
from pypdf import PdfReader, PdfWriter


def merge_pdfs(pdf1_path: str, pdf2_path: str, output_path: str) -> None:
    """
    将两个 PDF 文件合并为一个。

    Args:
        pdf1_path: 第一个 PDF 文件路径
        pdf2_path: 第二个 PDF 文件路径
        output_path: 输出 PDF 文件路径
    """
    # 检查输入文件是否存在
    for path in [pdf1_path, pdf2_path]:
        if not os.path.exists(path):
            print(f"错误：文件不存在 -> {path}")
            sys.exit(1)
        if not path.lower().endswith(".pdf"):
            print(f"警告：文件可能不是 PDF 格式 -> {path}")

    writer = PdfWriter()

    # 依次读取并添加每个 PDF 的页面
    for idx, pdf_path in enumerate([pdf1_path, pdf2_path], start=1):
        reader = PdfReader(pdf_path)
        page_count = len(reader.pages)
        print(f"  第 {idx} 个文件：{pdf_path}（共 {page_count} 页）")
        for page in reader.pages:
            writer.add_page(page)

    # 写入输出文件
    with open(output_path, "wb") as output_file:
        writer.write(output_file)

    total_pages = len(writer.pages)
    print(f"\n✅ 合并完成！")
    print(f"   输出文件：{output_path}")
    print(f"   总页数：{total_pages} 页")


def main():
    if len(sys.argv) < 3:
        print("用法: python merge_pdfs.py <pdf1> <pdf2> [输出文件名]")
        print("示例: python merge_pdfs.py file1.pdf file2.pdf merged.pdf")
        sys.exit(1)

    pdf1 = sys.argv[1]
    pdf2 = sys.argv[2]

    # 默认输出文件名
    if len(sys.argv) >= 4:
        output = sys.argv[3]
    else:
        output = "merged_output.pdf"

    print(f"开始合并 PDF：")
    merge_pdfs(pdf1, pdf2, output)


if __name__ == "__main__":
    main()
