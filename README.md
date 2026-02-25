# Software Engineering and DevOps Coursework 1 Repository


## Repository Contents
- `Dec2Hex.py`: Initial Python script for decimal-to-hex conversion.
- `test_Dec2Hex.py`: Unit test file (added in Task 5).
- `README.md`: This file (setup guide based on Lab 5 and coursework specs).
- (Optional) Other files: Jenkins configs, SonarQube reports (for evidence).

## Prerequisites
- AWS Account (with EC2 access).
- GitHub Account (added as collaborator to this repo).
- Local machine with SSH client (e.g., Git Bash for Windows).
- Familiarity with Bash commands (see Lab 5 tutorial links).
- Python 3 installed on EC2 instance.

## Setup Instructions
Follow these steps to complete the practical component (40 marks). Based on Lab 5: Automation and Jenkins, and Coursework Tasks 1-6.

Group members: Clone this repository (https://github.com/Cairnstew/Group_4_Coursework_1). You may already be added as collaborators. Configure Git with your name and email before contributing.

### Task 1: Deploy AWS EC2 Instance (3 marks)
1. Launch an EC2 instance via AWS Console:
   - Instance Type: t2.large (more resources than previous labs).
   - OS: Up-to-date Ubuntu (AMI: Ubuntu Server 22.04 LTS or similar).
   - Storage: 8GB volume.
   - Security Group: Open ports 22 (SSH), 8080 (Jenkins), 9000 (SonarQube).
     - Inbound Rules:
       - SSH (TCP, Port 22, Source: Anywhere or your IP).
       - Custom TCP (Port 8080, Source: Anywhere).
       - Custom TCP (Port 9000, Source: Anywhere).
   - Key Pair: Create or use existing for SSH access.

2. Connect via SSH:
   ```
   ssh -i your-key.pem ubuntu@your-ec2-public-ip
   ```

3. Install Python, Git, and Jenkins:
   ```
   sudo apt update
   sudo apt install -y python3 python3-pip git
   ```
   (Jenkins installation detailed in Task 3.)

**Note:** Stop/terminate instance when not in use to avoid costs.

### Task 2: Configure Git and GitHub Repository (3 marks)
1. On EC2 instance (or locally), configure Git:
   ```
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

2. Clone this repository:
   ```
   git clone https://github.com/Cairnstew/Group_4_Coursework_1.git
   cd Group_4_Coursework_1
   ```

3. Add or update `Dec2Hex.py` (If not there):
   ```python
   import sys

   def decimal_to_hex(decimal_value):
       hex_chars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F']
       hexadecimal = ""
       num = decimal_value
       print(f"Converting the Decimal Value {num} to Hex...")
       while num != 0:
           rem = num % 16
           hexadecimal = hex_chars[rem] + hexadecimal
           num //= 16
       print(f"Hexadecimal representation is: {hexadecimal}")
       return hexadecimal

   if __name__ == "__main__":
       if len(sys.argv) > 1:
           try:
               decimal_value = int(sys.argv[1])
               decimal_to_hex(decimal_value)
           except ValueError:
               print("Please provide a valid integer.")
       else:
           print("Usage: python script.py <decimal_number>")
   ```

4. Commit and push (if changes made):
   ```
   git add Dec2Hex.py
   git commit -m "Initial commit: Add Dec2Hex.py"
   git push origin main
   ```
   Verify file appears on GitHub.

### Task 3: Configure Jenkins Freestyle Project (2+2+2 marks)
1. Install Jenkins (from Lab 5):
   ```
   curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
   echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
   sudo apt-get update
   sudo apt install -y ca-certificates fontconfig openjdk-17-jre default-jdk jenkins
   sudo systemctl start jenkins
   sudo systemctl enable jenkins
   ```

2. Access Jenkins: `http://your-ec2-ip:8080`.
   - Unlock with admin password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`.
   - Install suggested plugins.
   - Create admin account.
   - Install additional plugins: Groovy, Docker Pipeline, SSH Agent, SSH Pipeline Steps.
   - Restart: `http://your-ec2-ip:8080/restart`.

3. Create Freestyle Project:
   - New Item > Freestyle project > Name: "Dec2Hex-CI".
   - Source Code Management: Git > Repository URL: https://github.com/Cairnstew/Group_4_Coursework_1.git.
   - Credentials: Add GitHub Personal Access Token (repo scope, 7-day expiration).
   - Build Triggers: Poll SCM (e.g., `* * * * *` for every minute).
   - Build Steps: Execute Shell:
     ```
     python3 Dec2Hex.py 15  # Example input
     ```

4. Build Now: Check console output for auto-detect changes, compile, and run.

### Task 4: Implement Static Code Analysis with SonarQube (10 marks)
1. Install SonarQube on EC2 (Port 9000 open).
   - Follow official docs: https://docs.sonarsource.com/sonarqube/latest/setup-and-upgrade/install-the-server/.
   - Basic setup: Download, run as service.

2. Install SonarScanner:
   ```
   sudo apt install -y unzip
   wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
   unzip sonar-scanner-cli-5.0.1.3006-linux.zip
   sudo mv sonar-scanner-5.0.1.3006 /opt/sonar-scanner
   sudo chown -R ubuntu:ubuntu /opt/sonar-scanner
   echo 'export PATH="$PATH:/opt/sonar-scanner/bin"' >> ~/.bashrc
   source ~/.bashrc
   ```

3. In Jenkins Project: Add Build Step for SonarScanner.
   - Configure sonar-project.properties in repo root:
     ```
     sonar.projectKey=Dec2Hex
     sonar.sources=.
     sonar.language=py
     sonar.host.url=http://localhost:9000
     sonar.login=your-sonar-token
     ```
   - Execute Shell: `sonar-scanner`.

4. Run build and view SonarQube report at `http://your-ec2-ip:9000`.

### Task 5: Improve Python Project with Error Handling and Tests (10 marks)
1. Extend `Dec2Hex.py`:
   - Error if no input.
   - Handle non-integer inputs without crashing.

2. Add Unit Tests (`test_Dec2Hex.py` using unittest):
   ```python
   import unittest
   from Dec2Hex import decimal_to_hex

   class TestDecimalToHex(unittest.TestCase):
       def test_valid_input(self):
           self.assertEqual(decimal_to_hex(15), 'F')

       def test_no_input(self):
           with self.assertRaises(SystemExit):
               decimal_to_hex(None)  # Simulate no input

       def test_invalid_input(self):
           self.assertIsNone(decimal_to_hex('abc'))  # Return None or handle

   if __name__ == '__main__':
       unittest.main()
   ```

3. Commit changes with Git: Use meaningful commits to track development.

### Task 6: Run CI Pipeline and Fix Issues (8 marks)
1. Push changes; Jenkins auto-builds.
2. Address SonarQube feedback (e.g., code smells).
3. Ensure all tests pass; build succeeds.
4. Use Git for version control (branching if needed).

## Usage
- Run script: `python3 Dec2Hex.py 15` → Output: "F".
- Jenkins: Auto-triggers on push.
- SonarQube: Analyzes code quality.

## Evidence Collection (for Submission)
1. Jenkins Console Output (original + updated code).
2. SonarQube Screenshot.
3. Final Code Files.
4. Git Log: `git log --oneline`.
5. Unit Test Files.

## Video Demonstration (5 min max)
- Record pushing changes, Jenkins auto-build, console output, SonarQube report.
- Use Screencast-O-Matic; upload to GCU OneDrive; share link.
- Name: Group_Name_DevOps_CW1.mp4.
