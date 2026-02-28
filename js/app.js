document.addEventListener('DOMContentLoaded', () => {
    const navItems = document.querySelectorAll('.nav-item');
    const toolSections = document.querySelectorAll('.tool-section');
    const toolTitle = document.getElementById('current-tool-title');

    // Sidebar navigation logic
    navItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            
            // Remove active class from all items
            navItems.forEach(nav => nav.classList.remove('active'));
            
            // Add active class to clicked item
            item.classList.add('active');
            
            // Update title
            toolTitle.textContent = item.querySelector('span').textContent;
            
            // Hide all sections
            toolSections.forEach(section => section.classList.remove('active'));
            
            // Show target section
            const targetId = item.getAttribute('data-tool');
            document.getElementById(targetId).classList.add('active');
        });
    });
});
