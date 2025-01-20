document.addEventListener('DOMContentLoaded', async function() {
    // 다크모드 적용
    document.body.classList.add('dark-mode');
    
    // 스크롤 관련 동작 초기화
    const navbar = document.querySelector('.ftco-navbar-light');
    if (navbar) {
        // 초기 상태 설정
        navbar.style.display = 'block';
        navbar.style.position = 'fixed';
        navbar.style.top = '0';
        navbar.style.background = '#242424';
        navbar.classList.add('scrolled');
        
        // 기존 스크롤 이벤트 리스너 제거 및 새로운 설정 적용
        window.addEventListener('scroll', function() {
            navbar.style.display = 'block';
            navbar.style.position = 'fixed';
            navbar.style.top = '0';
            navbar.classList.add('scrolled');
        });
    }

    // 카테고리별 이모지 매핑
    const categoryEmojis = {
        'APPLICATION': '💻',
        'HACKING': '🔓',
        'DASHBOARD': '📊',
        'DEVOPS': '⚙️',
        'IDS': '🛡️',
        'MALWARE': '🦠',
        'NETWORK': '🌐',
        'SQL': '💾'
    };

    // 카테고리별 포스트 로드 함수
    async function loadCategoryPosts(category) {
        try {
            const response = await fetch(`/jinyeong001/posts/${category}/index.json`);
            // const response = await fetch(`/posts/${category}/index.json`);
            if (!response.ok) {
                console.error(`Error loading ${category} posts:`, response.statusText);
                return [];
            }
            const data = await response.json();
            return data.posts || [];
        } catch (error) {
            console.error(`Error loading ${category} posts:`, error);
            return [];
        }
    }

    // 마크다운 파일 로드 및 변환 함수
    async function loadMarkdownPost(category, filename) {
        try {
            const response = await fetch(`/jinyeong001/posts/${category}/${filename}`);
            // const response = await fetch(`/posts/${category}/${filename}`);
            const markdown = await response.text();
            // marked.js를 사용하여 마크다운을 HTML로 변환
            const html = marked.parse(markdown);
            return html;
        } catch (error) {
            console.error('Error loading markdown:', error);
            return '<p>포스트를 불러올 수 없습니다.</p>';
        }
    }

    // 목차 생성 함수
    function generateTOC(content) {
        const tocList = document.getElementById('toc-list');
        const postContent = document.getElementById('post-content');
        tocList.innerHTML = '';
        
        // 컨텐츠를 실제 DOM에 적용
        postContent.innerHTML = content;
        
        // 실제 DOM에서 헤더 요소들을 찾음
        const headers = postContent.querySelectorAll('h1, h2, h3');
        const headerPositions = [];
        
        headers.forEach((header, index) => {
            const headerId = `section-${index}`;
            header.id = headerId;
            
            const li = document.createElement('li');
            li.className = 'nav-item';
            const level = parseInt(header.tagName.charAt(1));
            li.style.paddingLeft = `${(level - 1) * 15}px`;
            
            const link = document.createElement('a');
            link.className = 'nav-link';
            link.href = `#${headerId}`;
            link.textContent = header.textContent;
            
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const target = document.getElementById(headerId);
                if (target) {
                    const offset = target.offsetTop - 100;
                    window.scrollTo({
                        top: offset,
                        behavior: 'smooth'
                    });
                    
                    // 클릭한 링크 활성화
                    document.querySelectorAll('#toc-list .nav-link').forEach(l => {
                        l.classList.remove('active');
                    });
                    link.classList.add('active');
                }
            });
            
            li.appendChild(link);
            tocList.appendChild(li);
            
            // 헤더 위치 저장
            headerPositions.push({
                id: headerId,
                top: header.offsetTop
            });
        });

        // 스크롤 이벤트 핸들러
        const handleScroll = () => {
            const scrollPosition = window.scrollY + 150;
            let activeSection = null;
            
            // 현재 스크롤 위치에 해당하는 섹션 찾기
            for (let i = 0; i < headerPositions.length; i++) {
                if (scrollPosition >= headerPositions[i].top) {
                    activeSection = headerPositions[i].id;
                }
            }
            
            // 목차 항목 활성화 상태 업데이트
            if (activeSection) {
                document.querySelectorAll('#toc-list .nav-link').forEach(link => {
                    link.classList.remove('active');
                    if (link.getAttribute('href') === `#${activeSection}`) {
                        link.classList.add('active');
                    }
                });
            }
        };

        // 스크롤 이벤트 리스너 등록
        window.removeEventListener('scroll', handleScroll);
        window.addEventListener('scroll', handleScroll);
        
        // 초기 활성화 상태 설정
        setTimeout(handleScroll, 200);
    }

    // URL 파라미터 파싱 함수 수정
    function getPostFromUrl() {
        // URL에서 ? 이후의 문자열을 가져옴
        const query = window.location.search.substring(1);
        return query ? decodeURIComponent(query) : null;
    }

    // createPostList 함수 수정
    async function createPostList() {
        const postList = document.getElementById('post-items');
        const categories = ['APPLICATION', 'HACKING', 'DASHBOARD', 'DEVOPS', 'IDS', 'MALWARE', 'NETWORK', 'SQL'];
        const targetPost = getPostFromUrl();
        
        for (const category of categories) {
            const groupDiv = document.createElement('div');
            groupDiv.className = 'category-group';
            
            const categoryBtn = document.createElement('button');
            categoryBtn.className = 'category-btn';
            categoryBtn.innerHTML = `${categoryEmojis[category]} ${category}`;
            categoryBtn.style.pointerEvents = 'none';
            
            const postsContainer = document.createElement('div');
            postsContainer.className = 'posts-container show';
            postsContainer.dataset.category = category;
            
            groupDiv.appendChild(categoryBtn);
            groupDiv.appendChild(postsContainer);
            postList.appendChild(groupDiv);
            
            const posts = await loadCategoryPosts(category.toLowerCase());
            if (posts.length > 0) {
                posts.forEach(post => {
                    const item = document.createElement('div');
                    item.className = 'post-item';
                    item.textContent = post.title;
                    item.style.cursor = 'pointer';
                    
                    // URL 업데이트 추가
                    item.addEventListener('click', async () => {
                        const content = await loadMarkdownPost(category.toLowerCase(), post.filename);
                        document.getElementById('post-content').innerHTML = content;
                        generateTOC(content);
                        
                        // URL 업데이트 (포스트 제목만 사용)
                        const newUrl = `${window.location.pathname}?${post.title}`;
                        window.history.pushState({}, '', newUrl);
                        
                        document.querySelectorAll('.post-item').forEach(p => {
                            p.classList.remove('active');
                        });
                        item.classList.add('active');
                    });
                    
                    postsContainer.appendChild(item);
                    
                    // URL과 포스트 제목이 일치하면 자동 로드
                    if (targetPost === post.title) {
                        item.click(); // 해당 포스트 자동 클릭
                    }
                });
            }
        }
    }

    // 페이지 로드 시 URL 확인
    createPostList();

    // 스크롤 이벤트 추가
    window.addEventListener('scroll', function() {
        const scrollPosition = window.scrollY;
        
        // 현재 화면에 보이는 섹션 찾기
        document.querySelectorAll('[id^="section-"]').forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionBottom = sectionTop + section.offsetHeight;
            
            if (scrollPosition >= sectionTop - 100 && scrollPosition < sectionBottom) {
                // 해당 섹션의 목차 항목 활성화
                document.querySelectorAll('#toc-list .nav-link').forEach(link => {
                    link.classList.remove('active');
                    if (link.getAttribute('href') === `#${section.id}`) {
                        link.classList.add('active');
                    }
                });
            }
        });
    });
});
