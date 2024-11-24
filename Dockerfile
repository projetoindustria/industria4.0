FROM maven AS build
WORKDIR /build
COPY . .
RUN mvn clean package -DskipTests

FROM eclipse-temurin AS run
WORKDIR /app
COPY --from=build ./build/target/*.jar ./app.jar

ENTRYPOINT java -jar app.jar
