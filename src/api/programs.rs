use std::sync::Arc;

use key_lock::KeyLock;
use poem_ext::response;
use poem_openapi::{param::Path, payload::Json, OpenApi};
use uuid::Uuid;

use crate::{
    config::Config,
    environments::Environments,
    program::{
        build_program, delete_program, run_program, BuildProgramError, DeleteProgramError,
        RunProgramError,
    },
    schemas::{
        BuildProgramRequest, BuildResult, BuildRunResult, RunProgramRequest, RunRequest, RunResult,
    },
};

use super::Tags;

pub struct ProgramsApi {
    pub config: Arc<Config>,
    pub environments: Arc<Environments>,
    pub compile_lock: KeyLock<Uuid>,
}

#[OpenApi(tag = "Tags::Programs")]
impl ProgramsApi {
    /// Upload and immediately run a program.
    #[oai(path = "/run", method = "post")]
    async fn run(&self, data: Json<RunRequest>) -> Run::Response {
        let BuildResult {
            program_id,
            compile_result,
        } = match build_program(
            &self.config,
            &self.environments,
            data.0.build,
            &self.compile_lock,
        )
        .await
        {
            Ok(result) => result,
            Err(BuildProgramError::EnvironmentNotFound(_)) => return Run::environment_not_found(),
            Err(BuildProgramError::CompilationFailed(result)) => return Run::compile_error(result),
            Err(err) => return Err(err.into()),
        };

        match run_program(&self.config, &self.environments, program_id, data.0.run).await {
            Ok(run_result) => Run::ok(BuildRunResult {
                program_id,
                build: compile_result,
                run: run_result,
            }),
            Err(err) => Err(err.into()),
        }
    }

    /// Upload and compile a program.
    #[oai(path = "/programs", method = "post")]
    async fn build_program(&self, data: Json<BuildProgramRequest>) -> BuildProgram::Response {
        match build_program(&self.config, &self.environments, data.0, &self.compile_lock).await {
            Ok(result) => BuildProgram::ok(result),
            Err(BuildProgramError::EnvironmentNotFound(_)) => BuildProgram::environment_not_found(),
            Err(BuildProgramError::CompilationFailed(result)) => {
                BuildProgram::compile_error(result)
            }
            Err(err) => Err(err.into()),
        }
    }

    /// Run a program that has been uploaded previously.
    #[oai(path = "/programs/:program_id/run", method = "post")]
    async fn run_program(
        &self,
        program_id: Path<Uuid>,
        data: Json<RunProgramRequest>,
    ) -> RunProgram::Response {
        match run_program(&self.config, &self.environments, program_id.0, data.0).await {
            Ok(result) => RunProgram::ok(result),
            Err(RunProgramError::ProgramNotFound) => RunProgram::not_found(),
            Err(err) => Err(err.into()),
        }
    }

    /// Delete a program.
    #[oai(path = "/programs/:program_id", method = "delete")]
    async fn delete_program(&self, program_id: Path<Uuid>) -> DeleteProgram::Response {
        match delete_program(&self.config, program_id.0).await {
            Ok(_) => DeleteProgram::ok(),
            Err(DeleteProgramError::ProgramNotFound) => DeleteProgram::not_found(),
            Err(err) => Err(err.into()),
        }
    }
}

response!(Run = {
    /// Code has been executed successfully.
    Ok(200) => BuildRunResult,
    /// Environment does not exist.
    EnvironmentNotFound(404, error),
    /// Code could not be compiled.
    CompileError(400, error) => RunResult,
});

response!(BuildProgram = {
    /// Program has been built successfully.
    Ok(201) => BuildResult,
    /// Environment does not exist.
    EnvironmentNotFound(404, error),
    /// Code could not be compiled.
    CompileError(400, error) => RunResult,
});

response!(RunProgram = {
    /// Code has been executed successfully.
    Ok(200) => RunResult,
    /// Program does not exist.
    NotFound(404, error),
});

response!(DeleteProgram = {
    /// Program has been deleted.
    Ok(200),
    /// Program does not exist.
    NotFound(404, error),
});
