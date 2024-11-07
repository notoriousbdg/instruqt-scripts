#!/bin/bash

# Function to install Java 19 silently
install_java_19() {
    echo "Java not found or not version 19. Installing OpenJDK 19 silently..."

    # Update package lists silently
    sudo apt-get update -qq

    # Install OpenJDK 19 silently
    sudo apt-get install -y -qq openjdk-19-jre-headless
}

# Check if Java is installed and if it's version 19
if command -v java &> /dev/null; then
    java_version=$(java -version 2>&1 | awk -F[\"\.] 'NR==1{print $2}')
    if [ "$java_version" -ne 19 ]; then
        echo "Java version $java_version is installed, but version 19 is required."
        install_java_19
    else
        echo "Java 19 is already installed."
    fi
else
    echo "Java is not installed."
    install_java_19
fi

# Run the JAR file with Java 19
echo "Running log-generator-0.0.1-SNAPSHOT.jar with Java 19..."
cd download-s3
java -jar log-generator-0.0.1-SNAPSHOT.jar