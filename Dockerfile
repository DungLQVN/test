# Stage 1: Build the React Frontend
# Sử dụng Node.js image để cài đặt dependencies và build ứng dụng React
FROM node:20-alpine AS frontend_builder

WORKDIR /app

# Copy package.json và package-lock.json trước để tận dụng Docker cache
# nếu các dependencies không thay đổi
COPY package.json package-lock.json ./

# Cài đặt tất cả các dependencies (bao gồm devDependencies cho việc build)
RUN npm install

# Copy toàn bộ mã nguồn của ứng dụng vào thư mục làm việc
COPY . .

# Build ứng dụng React (tạo ra các tệp tĩnh trong thư mục 'build')
RUN npm run build

# Stage 2: Serve the Node.js Backend and React Frontend
# Sử dụng Node.js image nhẹ hơn cho môi trường runtime
FROM node:20-alpine AS final_server

WORKDIR /app

# Copy package.json và package-lock.json để cài đặt chỉ các production dependencies
# cần thiết cho Express server.
COPY package.json package-lock.json ./

# Cài đặt chỉ các production dependencies
RUN npm install --production

# Copy tệp server (index.js)
COPY index.js ./

# Copy thư mục 'public' (nếu có các tệp tĩnh dùng trong quá trình phát triển)
# Hoặc bỏ qua nếu chỉ phục vụ từ thư mục 'build'
COPY public ./public

# Copy thư mục 'build' từ stage 'frontend_builder'
# Đây là các tệp React đã được build
COPY --from=frontend_builder /app/build ./build

# Mở cổng mà ứng dụng Express lắng nghe
# Ứng dụng của bạn lắng nghe trên PORT 3000
EXPOSE 3000

# Lệnh để khởi chạy ứng dụng khi container bắt đầu
# "start" script trong package.json của bạn là "node index.js"
CMD ["npm", "start"]