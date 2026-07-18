# Miners Online Infrastructure

This repository contains the infrastructure code for the Miners Online project. It includes Docker Compose configurations, environment variables, and other necessary files to set up and run the project's services.

## Getting Started

To get started with the Miners Online Infrastructure, follow these steps:

1. Clone the repository:
   ```bash
   git clone https://github.com/miners-online/infra.git
   cd infra
   ```
2. Install Docker and Docker Compose if you haven't already. You can find installation instructions on the [Docker website](https://docs.docker.com/get-docker/).
3. Create a `.env` file in the root directory of the project and configure the necessary environment variables. You can use the provided `.env.example` file as a template:
   ```bash
   cp .env.example .env
   ```
4. Start the core services using Docker Compose:
   ```bash
   docker compose -f core.docker-compose.yml up -d
   ```
5. Start the game services using Docker Compose:
   ```bash
   docker compose -f games.docker-compose.yml up -d
   ```

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for more details.
