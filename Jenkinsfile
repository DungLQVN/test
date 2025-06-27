// Định nghĩa agent (môi trường chạy pipeline)
// agent {
//     docker {
//         image 'node:16-alpine' // Image cơ bản có Node.js
//         args '-u root' // Chạy với quyền root nếu cần cài đặt thêm công cụ
//     }
// }

// Khai báo các công cụ sẽ được Jenkins tự động tải xuống hoặc sử dụng (nếu đã cấu hình trong Global Tool Configuration)
tools {
    // nodejs 'NodeJS_16' // Tên cấu hình Node.js trong Jenkins Global Tool Configuration
    // maven 'Maven_3.8' // Tên cấu hình Maven (thường cần cho Sonar Scanner CLI nếu không dùng Gradle)
}

// Định nghĩa các biến môi trường
environment {
    // Thông tin Docker Registry
    DOCKER_REGISTRY = 'your-docker-registry.com' // Thay thế bằng địa chỉ Docker Registry của bạn (ví dụ: docker.io/your_username)
    DOCKER_IMAGE_NAME = 'your-app-name' // Tên ứng dụng của bạn
    // ID của Docker Registry Credential trong Jenkins (kiểu 'Username with password')
    DOCKER_CREDENTIALS_ID = 'docker-hub-credentials'

    // Thông tin SonarQube
    SONAR_SCANNER_HOME = tool 'SonarScanner' // Tên cấu hình SonarScanner trong Jenkins Global Tool Configuration
    SONAR_PROJECT_KEY = 'your-app-sonar-key' // Key duy nhất cho dự án SonarQube của bạn
    SONAR_HOST_URL = 'http://your-sonarqube-server.com' // Địa chỉ SonarQube server
    // ID của SonarQube Token Credential trong Jenkins (kiểu 'Secret text')
    SONAR_AUTH_TOKEN_ID = 'sonarqube-token'

    // Thông tin GitOps (ArgoCD)
    GITOPS_REPO_URL = 'https://github.com/your-org/your-gitops-repo.git' // Kho GitOps chứa K8s manifests
    GITOPS_BRANCH = 'main' // Nhánh của kho GitOps
    // ID của Git Credential (SSH Key hoặc Username with password) cho kho GitOps
    GITOPS_CREDENTIALS_ID = 'github-gitops-credentials'
    K8S_MANIFEST_PATH = 'k8s/deployment.yaml' // Đường dẫn đến file Deployment YAML trong kho GitOps

    // Thư mục để lưu báo cáo OWASP Dependency-Check
    OWASP_REPORT_DIR = 'owasp-reports'
}

// Khối pipeline chính
pipeline {
    // Định nghĩa các giai đoạn (stages) của pipeline
    stages {
        stage('Checkout Source Code') {
            steps {
                script {
                    echo "Checking out application source code from SCM..."
                    // URL repo của ứng dụng chính (ví dụ: https://github.com/DungLQVN/test.git)
                    // Sử dụng SCM mặc định của job hoặc chỉ định rõ
                    git branch: 'main', credentialsId: 'github-app-credentials', url: 'https://github.com/DungLQVN/test.git'
                }
            }
        }

        stage('Build & Test Application (NPM)') {
            steps {
                script {
                    // Sử dụng Node.js Tool được cấu hình trong Jenkins
                    // tool 'NodeJS_16' // Nếu bạn đã định nghĩa tool NodeJS trong Jenkins
                    echo "Installing Node.js dependencies..."
                    sh 'npm install'

                    echo "Building application..."
                    sh 'npm run build' // Hoặc lệnh build phù hợp với dự án của bạn

                    echo "Running unit tests..."
                    sh 'npm test' // Đảm bảo test không lỗi để pipeline tiếp tục
                }
            }
        }

        stage('Static Code Analysis (SonarQube)') {
            // Chỉ chạy giai đoạn này nếu stage trước thành công
            when {
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
            }
            steps {
                script {
                    echo "Running SonarQube analysis..."
                    // Lấy SonarQube Token từ Jenkins Credentials
                    withCredentials([string(credentialsId: env.SONAR_AUTH_TOKEN_ID, variable: 'SONAR_TOKEN')]) {
                        // Sử dụng SonarQube Scanner được cấu hình
                        withSonarQubeEnv(installationName: SONAR_SCANNER_HOME) { // Tên cấu hình SonarScanner
                            sh "${SONAR_SCANNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=${SONAR_PROJECT_KEY} " +
                               "-Dsonar.sources=. -Dsonar.host.url=${SONAR_HOST_URL} " +
                               "-Dsonar.login=${SONAR_TOKEN}"
                            // Thêm các tham số khác nếu cần, ví dụ: -Dsonar.tests=. -Dsonar.test.inclusions='**/*.spec.js'
                        }
                    }
                    echo "SonarQube analysis finished. Check results on SonarQube server."
                }
            }
        }

        stage('Dependency Security Scan (OWASP Dependency-Check)') {
            // Chỉ chạy giai đoạn này nếu stage trước thành công
            when {
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
            }
            steps {
                script {
                    echo "Running OWASP Dependency-Check scan..."
                    // Tạo thư mục để lưu báo cáo
                    sh "mkdir -p ${OWASP_REPORT_DIR}"
                    // Chạy Dependency-Check CLI
                    // Đảm bảo 'dependency-check.sh' (hoặc .bat) có trong PATH của agent
                    // Hoặc bạn phải cung cấp đường dẫn đầy đủ đến nó.
                    // -f JUNIT: xuất báo cáo định dạng JUnit để Jenkins có thể hiển thị kết quả test
                    // -o: thư mục output
                    // --scan: thư mục cần scan
                    sh "dependency-check.sh --scan . --format HTML --format JUNIT --out ${OWASP_REPORT_DIR}"
                    // Đăng tải kết quả JUnit để Jenkins hiển thị
                    junit "${OWASP_REPORT_DIR}/dependency-check-report.xml"
                    echo "OWASP Dependency-Check scan finished. Check reports in ${OWASP_REPORT_DIR}/"
                }
            }
        }

        stage('Build & Push Docker Image') {
            // Chỉ chạy giai đoạn này nếu stage trước thành công
            when {
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
            }
            steps {
                script {
                    echo "Building Docker image: ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}..."
                    // Docker build
                    // --pull: luôn kéo base image mới nhất
                    // -t: tag image
                    sh "docker build --pull -t ${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} ."

                    echo "Logging into Docker Registry: ${DOCKER_REGISTRY}..."
                    // Sử dụng credentials đã cấu hình trong Jenkins
                    withCredentials([usernamePassword(credentialsId: env.DOCKER_CREDENTIALS_ID, usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        sh "echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin ${DOCKER_REGISTRY}"
                    }

                    echo "Pushing Docker image to registry..."
                    sh "docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}"

                    echo "Docker image pushed: ${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}"
                }
            }
        }

        stage('GitOps Deployment (ArgoCD)') {
            // Chỉ chạy giai đoạn này nếu stage trước thành công
            when {
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
            }
            steps {
                script {
                    echo "Starting GitOps deployment via ArgoCD..."
                    // Clone kho GitOps
                    dir('gitops-repo') { // Clone vào một thư mục riêng để tránh lẫn lộn
                        git branch: env.GITOPS_BRANCH, credentialsId: env.GITOPS_CREDENTIALS_ID, url: env.GITOPS_REPO_URL
                    }

                    // Cập nhật file Kubernetes manifest với tag image mới
                    // Sử dụng 'sed' để thay thế image tag trong deployment.yaml
                    // Cần đảm bảo rằng file YAML của bạn có cấu trúc phù hợp để 'sed' có thể tìm và thay thế dễ dàng
                    // Ví dụ: image: your-docker-registry.com/your-app-name:old-tag
                    sh """
                        cd gitops-repo
                        # Thay thế dòng image bằng tag mới
                        # Đây là một ví dụ đơn giản, bạn cần điều chỉnh regex cho phù hợp với file YAML của mình
                        # Hoặc sử dụng yq (https://github.com/mikefarah/yq) nếu file YAML phức tạp hơn
                        sed -i "s|image: ${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:.*|image: ${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}|" ${K8S_MANIFEST_PATH}
                        git config user.email "jenkins@yourdomain.com"
                        git config user.name "Jenkins Automation"
                        git add ${K8S_MANIFEST_PATH}
                        git commit -m "Update ${DOCKER_IMAGE_NAME} image to ${BUILD_NUMBER} [skip ci]"
                        git push origin ${env.GITOPS_BRANCH}
                    """
                    echo "Updated Kubernetes manifest in GitOps repository. ArgoCD will now sync and deploy."
                    echo "Application is being deployed to Kubernetes cluster (3 nodes) via ArgoCD."
                }
            }
        }

        // --- Giai đoạn tùy chọn: Dynamic Application Security Testing (DAST) với OWASP ZAP ---
        // Giai đoạn này thường được chạy sau khi ứng dụng đã được triển khai và đang chạy
        // Nó có thể là một Jenkins Job riêng biệt hoặc một phần của pipeline dài hơn.
        // Để chạy ZAP, bạn cần có URL của ứng dụng đã triển khai.
        // stage('Dynamic Application Security Testing (OWASP ZAP)') {
        //     when {
        //         expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
        //     }
        //     steps {
        //         script {
        //             echo "Running OWASP ZAP scan..."
        //             // Giả định bạn có một ứng dụng đã triển khai và có thể truy cập qua URL
        //             // APP_URL = 'http://your-deployed-app.com'
        //             // sh "zap.sh -cmd -quickurl ${APP_URL} -quickprogress -quickout ${OWASP_REPORT_DIR}/zap-report.html"
        //             echo "OWASP ZAP scan configured separately or needs application URL."
        //             // Để tích hợp ZAP hiệu quả, bạn cần xem xét các plugin ZAP cho Jenkins hoặc
        //             // gọi ZAP CLI từ một Docker container.
        //         }
        //     }
        // }
    }

    // Các hành động sau khi pipeline hoàn thành (thành công, thất bại, luôn chạy)
    post {
        always {
            // Dọn dẹp workspace
            echo 'Cleaning up workspace...'
            deleteDir() // Xóa thư mục làm việc của Jenkins
        }
        success {
            echo 'Pipeline completed successfully!'
            // Gửi thông báo thành công (ví dụ: Slack, Email)
            // slackSend channel: '#your-channel', message: "Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} succeeded! Status: ${currentBuild.currentResult}"
        }
        failure {
            echo 'Pipeline failed!'
            // Gửi thông báo thất bại
            // slackSend channel: '#your-channel', message: "Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} FAILED! Status: ${currentBuild.currentResult}", color: 'danger'
        }
    }
}
