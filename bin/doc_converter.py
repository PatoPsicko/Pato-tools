import sys
import os

def convert_pdf_to_docx(pdf_path, docx_path):
    # Ocultar salida de consola de pdf2docx si es posible
    from pdf2docx import Converter
    cv = Converter(pdf_path)
    cv.convert(docx_path)
    cv.close()

def convert_docx_to_pdf(docx_path, pdf_path):
    from docx2pdf import convert
    # Intentar conversión. (Nota: en Windows requiere MS Word instalado por debajo)
    convert(docx_path, pdf_path)

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Uso: python doc_converter.py <pdf2docx|docx2pdf> <input_path> <output_path>")
        sys.exit(1)
        
    mode = sys.argv[1]
    input_path = sys.argv[2]
    output_path = sys.argv[3]
    
    if not os.path.exists(input_path):
        print(f"Error: El archivo de entrada no existe -> {input_path}")
        sys.exit(1)
        
    try:
        if mode == "pdf2docx":
            convert_pdf_to_docx(input_path, output_path)
        elif mode == "docx2pdf":
            convert_docx_to_pdf(input_path, output_path)
        else:
            print("Error: Modo inválido. Use pdf2docx o docx2pdf.")
            sys.exit(1)
            
        print("SUCCESS")
    except Exception as e:
        print(f"Error durante conversión: {str(e)}")
        sys.exit(1)
