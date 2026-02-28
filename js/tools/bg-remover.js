import imglyRemoveBackground from "https://esm.sh/@imgly/background-removal@1.4.5";

document.addEventListener('DOMContentLoaded', () => {
    // UI Elements
    const dropZone = document.getElementById('drop-zone');
    const fileInput = document.getElementById('file-input');
    const resultArea = document.getElementById('result-area');
    const originalImage = document.getElementById('original-image');
    const processedImage = document.getElementById('processed-image');

    const loadingOverlay = document.getElementById('loading-overlay');
    const loadingText = document.getElementById('loading-text');
    const progressBar = document.getElementById('progress-bar');

    const btnReset = document.getElementById('btn-reset');
    const btnDownload = document.getElementById('btn-download');

    let processedBlobUrl = null;

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
        if (processedBlobUrl) {
            URL.revokeObjectURL(processedBlobUrl);
            processedBlobUrl = null;
        }
    });

    // Download Button
    btnDownload.addEventListener('click', () => {
        if (!processedBlobUrl) return;

        const a = document.createElement('a');
        a.href = processedBlobUrl;
        a.download = 'imagen_sin_fondo.png';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    });

    // Core Logic
    async function handleFile(file) {
        if (!file.type.startsWith('image/')) {
            alert('Por favor, selecciona un archivo de imagen válido.');
            return;
        }

        // Display Original Image
        const objectUrl = URL.createObjectURL(file);
        originalImage.src = objectUrl;

        // Hide Upload, Show Loading
        dropZone.style.display = 'none';
        loadingOverlay.classList.add('active');

        try {
            // Config for @imgly/background-removal
            const config = {
                progress: (key, current, total) => {
                    if (total === 0) return;
                    const percent = Math.round((current / total) * 100);
                    progressBar.style.width = `${percent}%`;
                    loadingText.textContent = `Procesando: ${key} (${percent}%)`;
                }
            };

            console.log("Iniciando eliminación de fondo...");
            loadingText.textContent = "Cargando modelos de IA...";
            progressBar.style.width = '10%';

            // Remove Background - Function exported by the CDN script
            const imageBlob = await imglyRemoveBackground(file, config);

            // Create object URL for the processed image
            processedBlobUrl = URL.createObjectURL(imageBlob);
            processedImage.src = processedBlobUrl;

            // Show Results
            loadingOverlay.classList.remove('active');
            resultArea.style.display = 'flex';

        } catch (error) {
            console.error('Error removing background:', error);
            alert('Hubo un error al procesar la imagen: ' + error.message);

            // Reset UI on error
            loadingOverlay.classList.remove('active');
            dropZone.style.display = 'flex';
        }
    }
});
