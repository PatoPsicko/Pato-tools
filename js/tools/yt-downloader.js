document.addEventListener('DOMContentLoaded', () => {
    const urlInput = document.getElementById('yt-url');
    const formatSelect = document.getElementById('yt-format');
    const qualitySelect = document.getElementById('yt-quality');
    const btnDownload = document.getElementById('btn-yt-download');

    const formArea = document.getElementById('yt-form-area');
    const resultArea = document.getElementById('yt-result-area');
    const resultTitle = document.getElementById('yt-result-title');
    const btnReset = document.getElementById('btn-yt-reset');
    const btnSave = document.getElementById('btn-yt-save');

    const loadingOverlay = document.getElementById('loading-overlay');
    const loadingText = document.getElementById('loading-text');

    formatSelect.addEventListener('change', () => {
        if (formatSelect.value === 'audio') {
            qualitySelect.style.display = 'none';
        } else {
            qualitySelect.style.display = 'block';
        }
    });

    btnDownload.addEventListener('click', async () => {
        const url = urlInput.value.trim();
        const type = formatSelect.value;
        const quality = qualitySelect.value;

        if (!url || !url.includes('youtube.com/') && !url.includes('youtu.be/')) {
            alert('Por favor, ingresa un enlace válido de YouTube.');
            return;
        }

        // Show loading state
        formArea.style.display = 'none';
        loadingOverlay.classList.add('active');
        loadingText.textContent = "Procesando y descargando video (esto puede tardar unos minutos)...";
        // Reset progress bar to full width as an indeterminate indicator
        const progressBar = document.getElementById('progress-bar');
        if (progressBar) {
            progressBar.style.width = '100%';
            progressBar.style.animation = 'pulse 1.5s infinite';
        }

        try {
            const response = await fetch('/api/yt-download', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ url, type, quality })
            });

            const data = await response.json();

            if (response.ok && data.success) {
                loadingOverlay.classList.remove('active');
                resultArea.style.display = 'flex';

                resultTitle.textContent = data.title;
                btnSave.href = data.fileUrl;
                // Force download attribute filename
                btnSave.download = data.fileUrl.split('/').pop();
            } else {
                throw new Error(data.error || 'Error desconocido al descargar.');
            }
        } catch (error) {
            console.error('Download error:', error);
            alert('Hubo un error: ' + error.message);
            loadingOverlay.classList.remove('active');
            formArea.style.display = 'flex';
        } finally {
            if (progressBar) progressBar.style.animation = 'none';
        }
    });

    btnReset.addEventListener('click', () => {
        urlInput.value = '';
        resultArea.style.display = 'none';
        formArea.style.display = 'flex';
    });
});
