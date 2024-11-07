#!/bin/bash

# Function to install Java 19
install_java_19() {
    echo "Java not found or not version 19. Installing OpenJDK 19..."

    # Install necessary utilities
    sudo apt update
    sudo apt install -y wget tar

    # Download OpenJDK 19
    wget https://download.oracle.com/java/19/archive/jdk-19.0.2_linux-x64_bin.tar.gz -O jdk-19_linux-x64_bin.tar.gz

    # Create directory for Java installations
    sudo mkdir -p /usr/lib/jvm

    # Extract the downloaded archive
    sudo tar -xzf jdk-19_linux-x64_bin.tar.gz -C /usr/lib/jvm

    # Remove the downloaded archive
    rm jdk-19_linux-x64_bin.tar.gz

    # Set up alternatives to manage multiple Java versions
    sudo update-alternatives --install /usr/bin/java java /usr/lib/jvm/jdk-19/bin/java 1919
    sudo update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/jdk-19/bin/javac 1919

    # Set Java 19 as the default
    sudo update-alternatives --set java /usr/lib/jvm/jdk-19/bin/java
    sudo update-alternatives --set javac /usr/lib/jvm/jdk-19/bin/javac

    # Verify installation
    java -version
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