document.addEventListener('DOMContentLoaded', () => {
    // UI Elements
    const dropZone = document.getElementById('doc-drop-zone');
    const fileInput = document.getElementById('doc-file-input');
    const resultArea = document.getElementById('doc-result-area');
    const resultTitle = document.getElementById('doc-result-title');
    
    const loadingOverlay = document.getElementById('loading-overlay');
    const loadingText = document.getElementById('loading-text');
    const progressBar = document.getElementById('progress-bar');
    
    const btnReset = document.getElementById('btn-doc-reset');
    const btnDownload = document.getElementById('btn-doc-save');
    
    // Drag and Drop Events
    dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropZone.classList.add('dragover');
    });

    dropZone.addEventListener('dragleave', () => {
        dropZone.classList.remove('dragover');
    });

    dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        dropZone.classList.remove('dragover');

        if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
            handleFile(e.dataTransfer.files[0]);
        }
    });

    // File Input Event
    fileInput.addEventListener('change', (e) => {
        if (e.target.files && e.target.files.length > 0) {
            handleFile(e.target.files[0]);
        }
    });

    // Reset Button
    btnReset.addEventListener('click', () => {
        dropZone.style.display = 'flex';
        resultArea.style.display = 'none';
        fileInput.value = '';
        btnDownload.href = '#';
    });

    // Core Logic
    async function handleFile(file) {
        let isDocx = file.name.toLowerCase().endsWith('.docx');
        let isPdf = file.name.toLowerCase().endsWith('.pdf');
        
        if (!isDocx && !isPdf) {
            alert('Por favor, selecciona un archivo válido (.docx o .pdf).');
            return;
        }

        const endpointUrl = "/api/convert-doc";
        
        // Hide Upload, Show Loading
        dropZone.style.display = 'none';
        loadingOverlay.classList.add('active');
        loadingText.textContent = isPdf ? "Convirtiendo PDF a Word..." : "Convirtiendo Word a PDF...";
        progressBar.style.width = '50%'; // Indeterminate, set to 50% for now
        
        try {
            // Read file as Base64 to send in JSON
            const reader = new FileReader();
            reader.readAsDataURL(file);
            
            reader.onload = async function () {
                const base64Content = reader.result.split(',')[1];
                
                const payload = {
                    fileName: file.name,
                    content: base64Content,
                    type: isPdf ? 'pdf2docx' : 'docx2pdf'
                };

                const response = await fetch(endpointUrl, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(payload)
                });

                const data = await response.json();

                if (data.success) {
                    // Success
                    progressBar.style.width = '100%';
                    setTimeout(() => {
                        loadingOverlay.classList.remove('active');
                        resultArea.style.display = 'flex';
                        
                        btnDownload.href = data.fileUrl;
                        btnDownload.download = data.outputName;
                        resultTitle.textContent = "Conversión Completada";
                        progressBar.style.width = '0%';
                    }, 500);
                } else {
                    throw new Error(data.error || "Error desconocido");
                }
            };
            
            reader.onerror = function (error) {
                throw new Error("Error al leer el archivo");
            };

        } catch (error) {
            console.error('Error convirtiendo documento:', error);
            alert('Hubo un error al procesar el documento: ' + error.message);
            
            // Reset UI on error
            loadingOverlay.classList.remove('active');
            dropZone.style.display = 'flex';
            progressBar.style.width = '0%';
        }
    }
});
