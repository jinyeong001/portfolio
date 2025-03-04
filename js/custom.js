// Labs 카테고리 필터링
document.addEventListener('DOMContentLoaded', function() {
    const categoryButtons = document.querySelectorAll('.filter-btn');
    const labItems = document.querySelectorAll('.lab-item');

    categoryButtons.forEach(button => {
        button.addEventListener('click', () => {
            // 활성 버튼 스타일 변경
            categoryButtons.forEach(btn => btn.classList.remove('active'));
            button.classList.add('active');

            // 필터링
            const filterValue = button.getAttribute('data-filter');
            
            if(filterValue === 'all') {
                labItems.forEach(item => item.style.display = 'block');
            } else {
                labItems.forEach(item => {
                    const categories = item.getAttribute('data-category').split(' ');
                    if(categories.includes(filterValue)) {
                        item.style.display = 'block';
                    } else {
                        item.style.display = 'none';
                    }
                });
            }
        });
    });
});