import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SimulationProgressEvent {
  const SimulationProgressEvent({
    required this.step,
    required this.action,
    required this.status,
    required this.detail,
    required this.popupState,
  });

  final int step;
  final String action;
  final String status;
  final String detail;
  final String popupState;

  factory SimulationProgressEvent.fromJson(Map<String, dynamic> json) {
    return SimulationProgressEvent(
      step: json['step'] as int? ?? 0,
      action: json['action'] as String? ?? 'simulation',
      status: json['status'] as String? ?? 'processing',
      detail: json['detail'] as String? ?? '',
      popupState: json['popup_state'] as String? ?? 'processing',
    );
  }

  Map<String, dynamic> toStepMap() {
    return {
      'step': step,
      'action': action,
      'status': status,
      'detail': detail,
    };
  }
}

class SimulationRunnerResult {
  const SimulationRunnerResult({
    required this.success,
    required this.status,
    required this.summary,
    required this.steps,
    required this.raw,
    this.error,
  });

  final bool success;
  final String status;
  final String summary;
  final List<Map<String, dynamic>> steps;
  final Map<String, dynamic> raw;
  final String? error;
}

class SimulationRunnerService {
  SimulationRunnerService._();

  static final SimulationRunnerService instance = SimulationRunnerService._();

  Future<SimulationRunnerResult> runNaverMapScenario({
    void Function(SimulationProgressEvent event)? onProgress,
  }) {
    return _runScenarioModule(
      moduleName: 'local_server.app.simulation.naver_map_scenario',
      fallbackSummary: '네이버 지도 시뮬레이션을 완료했습니다.',
      onProgress: onProgress,
    );
  }

  Future<SimulationRunnerResult> runMemoScenario({
    void Function(SimulationProgressEvent event)? onProgress,
  }) async {
    const memoText =
        '오늘은 평소보다 조금 일찍 눈을 떴다. 창문 사이로 들어오는 햇빛이 생각보다 따뜻해서, 괜히 하루가 괜찮을 것 같은 기분이 들었다. '
        '별다른 계획은 없었지만, 오히려 그래서 더 여유롭게 시간을 보낼 수 있었다. 커피를 천천히 마시면서 그동안 미뤄두었던 생각들을 정리해봤다. '
        '요즘 나는 어디로 가고 있는지, 무엇을 원하는지에 대해 스스로에게 질문을 던져봤다. 명확한 답은 나오지 않았지만, 그 과정 자체가 조금은 의미 있게 느껴졌다. '
        '오후에는 가볍게 산책을 나갔다. 바람이 적당히 불고, 사람들의 표정도 나쁘지 않아 보여서 괜히 마음이 편해졌다. '
        '특별한 일이 있었던 하루는 아니었지만, 이렇게 조용히 흘러가는 시간도 나쁘지 않다고 느꼈다. 오늘의 나는 조금은 괜찮았던 것 같다.';
    final memoBase64 = base64.encode(utf8.encode(memoText));

    return _runPowerShellScript(
      scriptName: 'run_memo_simulation.ps1',
      scriptArguments: ['-MemoBase64', memoBase64],
      fallbackSummary: '메모장 시나리오를 완료했습니다.',
      onProgress: onProgress,
    );
  }

  Future<SimulationRunnerResult> runWindowsThemeScenario({
    void Function(SimulationProgressEvent event)? onProgress,
  }) {
    return _runPowerShellScript(
      scriptName: 'run_windows_theme_simulation.ps1',
      fallbackSummary: 'Windows 테마 변경 시나리오를 완료했습니다.',
      onProgress: onProgress,
    );
  }

  Future<SimulationRunnerResult> runKakaoTalkScenario({
    void Function(SimulationProgressEvent event)? onProgress,
  }) {
    return _runScenarioModule(
      moduleName: 'local_server.app.simulation.kakaotalk_message_scenario',
      fallbackSummary:
          '\uce74\uce74\uc624\ud1a1 \uba54\uc2dc\uc9c0 \uc2dc\ub098\ub9ac\uc624\ub97c \uc644\ub8cc\ud588\uc2b5\ub2c8\ub2e4.',
      onProgress: onProgress,
    );
  }

  Future<SimulationRunnerResult> _runScenarioModule({
    required String moduleName,
    required String fallbackSummary,
    void Function(SimulationProgressEvent event)? onProgress,
  }) async {
    final root = _resolveProjectRoot();
    if (root == null) {
      return const SimulationRunnerResult(
        success: false,
        status: 'error',
        summary: '프로젝트 루트를 찾지 못했습니다.',
        steps: [],
        raw: {},
        error: 'root_not_found',
      );
    }

    final pythonCommand = _resolvePythonCommand(root, moduleName);
    if (pythonCommand == null) {
      return const SimulationRunnerResult(
        success: false,
        status: 'error',
        summary: 'Python 실행기를 찾지 못했습니다.',
        steps: [],
        raw: {},
        error: 'python_not_found',
      );
    }

    return _runProcess(
      executable: pythonCommand.executable,
      arguments: pythonCommand.arguments,
      workingDirectory: root.path,
      environment: {
        ...Platform.environment,
        'VOICE_NAVIGATOR_ROOT': root.path,
        'PLAYWRIGHT_HEADLESS': 'false',
        'PYTHONUTF8': '1',
        'PYTHONHOME': '',
        'PYTHONPATH': '',
      },
      fallbackSummary: fallbackSummary,
      onProgress: onProgress,
    );
  }

  Future<SimulationRunnerResult> _runPowerShellScript({
    required String scriptName,
    List<String> scriptArguments = const [],
    required String fallbackSummary,
    void Function(SimulationProgressEvent event)? onProgress,
  }) async {
    final root = _resolveProjectRoot();
    if (root == null) {
      return const SimulationRunnerResult(
        success: false,
        status: 'error',
        summary: '프로젝트 루트를 찾지 못했습니다.',
        steps: [],
        raw: {},
        error: 'root_not_found',
      );
    }

    final scriptPath =
        '${root.path}${Platform.pathSeparator}scripts${Platform.pathSeparator}$scriptName';
    if (!File(scriptPath).existsSync()) {
      return SimulationRunnerResult(
        success: false,
        status: 'error',
        summary: '$scriptName 스크립트를 찾지 못했습니다.',
        steps: const [],
        raw: const {},
        error: 'script_not_found',
      );
    }

    return _runProcess(
      executable: r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
      arguments: [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        ...scriptArguments,
      ],
      workingDirectory: root.path,
      environment: {
        ...Platform.environment,
        'VOICE_NAVIGATOR_ROOT': root.path,
      },
      fallbackSummary: fallbackSummary,
      onProgress: onProgress,
    );
  }

  Future<SimulationRunnerResult> _runProcess({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
    required Map<String, String> environment,
    required String fallbackSummary,
    void Function(SimulationProgressEvent event)? onProgress,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: true,
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stepList = <Map<String, dynamic>>[];
    Map<String, dynamic>? resultPayload;
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    void upsertStep(Map<String, dynamic> step) {
      final stepNo = step['step'];
      final index = stepList.indexWhere((item) => item['step'] == stepNo);
      if (index == -1) {
        stepList.add(step);
      } else {
        stepList[index] = step;
      }
    }

    Future<void> handleStdoutLine(String line) async {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        return;
      }
      stdoutBuffer.writeln(trimmed);

      try {
        final envelope = jsonDecode(trimmed) as Map<String, dynamic>;
        final kind = envelope['kind'] as String? ?? '';
        final payload = Map<String, dynamic>.from(
          envelope['payload'] as Map? ?? const <String, dynamic>{},
        );

        if (kind == 'progress') {
          final event = SimulationProgressEvent.fromJson(payload);
          upsertStep(event.toStepMap());
          onProgress?.call(event);
          return;
        }

        if (kind == 'result') {
          resultPayload = payload;
          final steps = (payload['steps'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList();
          if (steps.isNotEmpty) {
            stepList
              ..clear()
              ..addAll(steps);
          }
        }
      } catch (_) {
        // JSON이 아닌 stdout은 로그 버퍼로만 유지합니다.
      }
    }

    final stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          handleStdoutLine,
          onDone: () {
            if (!stdoutDone.isCompleted) {
              stdoutDone.complete();
            }
          },
        );

    final stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty) {
              stderrBuffer.writeln(trimmed);
            }
          },
          onDone: () {
            if (!stderrDone.isCompleted) {
              stderrDone.complete();
            }
          },
        );

    final exitCode = await process.exitCode;
    await Future.wait<void>([
      stdoutDone.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      ),
      stderrDone.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      ),
    ]);

    await stdoutSub.cancel();
    await stderrSub.cancel();

    if (exitCode != 0) {
      _appendDebugStep(
        stepList,
        title: 'process_error',
        detail: stderrBuffer.isNotEmpty
            ? stderrBuffer.toString()
            : stdoutBuffer.toString(),
      );
      return SimulationRunnerResult(
        success: false,
        status: 'error',
        summary: '시나리오 실행이 비정상 종료되었습니다.',
        steps: stepList,
        raw: {
          'stdout': stdoutBuffer.toString(),
          'stderr': stderrBuffer.toString(),
          'exit_code': exitCode,
        },
        error: stderrBuffer.isNotEmpty
            ? stderrBuffer.toString()
            : stdoutBuffer.toString(),
      );
    }

    if (resultPayload == null) {
      _appendDebugStep(
        stepList,
        title: 'missing_result_payload',
        detail: stdoutBuffer.toString().isEmpty
            ? 'stdout output is empty'
            : stdoutBuffer.toString(),
      );
      return SimulationRunnerResult(
        success: false,
        status: 'error',
        summary: '시나리오 결과를 받지 못했습니다.',
        steps: stepList,
        raw: {
          'stdout': stdoutBuffer.toString(),
          'stderr': stderrBuffer.toString(),
          'exit_code': exitCode,
        },
        error: 'missing_result_payload',
      );
    }

    final summary = (resultPayload!['route_summary'] as String?)?.trim();
    final reason = (resultPayload!['reason'] as String?)?.trim();
    final isSuccess = resultPayload!['status'] == 'success';

    if (!isSuccess) {
      _appendDebugStep(
        stepList,
        title: 'failure_reason',
        detail: reason ?? 'unknown reason',
      );
      final stdoutText = stdoutBuffer.toString().trim();
      if (stdoutText.isNotEmpty) {
        _appendDebugStep(stepList, title: 'stdout_debug', detail: stdoutText);
      }
      final stderrText = stderrBuffer.toString().trim();
      if (stderrText.isNotEmpty) {
        _appendDebugStep(stepList, title: 'stderr_debug', detail: stderrText);
      }
    }

    return SimulationRunnerResult(
      success: isSuccess,
      status: resultPayload!['status'] as String? ?? 'unknown',
      summary: isSuccess
          ? ((summary == null || summary.isEmpty) ? fallbackSummary : summary)
          : ((reason == null || reason.isEmpty)
              ? '시나리오 실행 중 오류가 발생했습니다.'
              : reason),
      steps: stepList,
      raw: resultPayload!,
      error: reason,
    );
  }

  _PythonCommand? _resolvePythonCommand(Directory root, String moduleName) {
    final projectRoot = root.path;
    final candidates = <_PythonCommand>[
      _PythonCommand(
        executable: '$projectRoot\\.venv-server\\Scripts\\python.exe',
        arguments: ['-m', moduleName],
      ),
      _PythonCommand(
        executable: 'python',
        arguments: ['-m', moduleName],
      ),
      _PythonCommand(
        executable: 'py',
        arguments: ['-3.11', '-m', moduleName],
      ),
      _PythonCommand(
        executable: 'py',
        arguments: ['-3', '-m', moduleName],
      ),
    ];

    for (final candidate in candidates) {
      if (_canExecute(candidate.executable)) {
        return candidate;
      }
    }
    return null;
  }

  Directory? _resolveProjectRoot() {
    final envRoot = Platform.environment['VOICE_NAVIGATOR_ROOT'];
    if (envRoot != null && envRoot.isNotEmpty) {
      final directory = Directory(envRoot);
      if (directory.existsSync()) {
        return directory;
      }
    }

    final roots = <Directory>[];

    void addAncestors(String startPath) {
      var dir = Directory(startPath);
      for (var i = 0; i < 8; i++) {
        roots.add(dir);
        final parent = dir.parent;
        if (parent.path == dir.path) {
          break;
        }
        dir = parent;
      }
    }

    addAncestors(Directory.current.path);
    addAncestors(File(Platform.resolvedExecutable).parent.path);

    for (final root in roots) {
      final candidate = File(
        '${root.path}${Platform.pathSeparator}local_server'
        '${Platform.pathSeparator}app${Platform.pathSeparator}simulation'
        '${Platform.pathSeparator}naver_map_scenario.py',
      );
      if (candidate.existsSync()) {
        return root;
      }
    }
    return null;
  }

  bool _canExecute(String executable) {
    if (executable.contains(Platform.pathSeparator)) {
      return File(executable).existsSync();
    }
    return true;
  }

  void _appendDebugStep(
    List<Map<String, dynamic>> steps, {
    required String title,
    required String detail,
  }) {
    steps.add(
      {
        'step': steps.length + 1,
        'action': title,
        'status': 'error',
        'detail': detail,
      },
    );
  }
}

class _PythonCommand {
  const _PythonCommand({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
}
