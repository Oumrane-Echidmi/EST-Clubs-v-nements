import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  Injectable,
  CallHandler,
  ExecutionContext,
  NestInterceptor,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Response } from 'express';
import { map } from 'rxjs/operators';
export class ApiError extends HttpException {
  constructor(code: string, message: string, status = 400) {
    super({ code, message }, status);
  }
}
@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(ApiExceptionFilter.name);
  catch(exception: unknown, host: ArgumentsHost) {
    let status = 500,
      code = 'INTERNAL_ERROR',
      message: string | string[] = 'An unexpected error occurred';
    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const body = exception.getResponse();
      const obj =
        typeof body === 'string'
          ? { message: body }
          : (body as { code?: string; message?: string | string[] });
      code =
        obj.code ??
        {
          400: 'VALIDATION_ERROR',
          401: 'UNAUTHORIZED',
          403: 'FORBIDDEN',
          404: 'NOT_FOUND',
          413: 'FILE_TOO_LARGE',
          429: 'RATE_LIMITED',
        }[status] ??
        'REQUEST_FAILED';
      message = obj.message ?? exception.message;
    } else if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      if (exception.code === 'P2002') {
        status = 409;
        code = 'CONFLICT';
        message = 'Resource already exists';
      }
      if (exception.code === 'P2025') {
        status = 404;
        code = 'NOT_FOUND';
        message = 'Resource not found';
      }
      if (exception.code === 'P2003') {
        status = 409;
        code = 'CONFLICT';
        message = 'Resource is referenced or does not exist';
      }
    }
    if (status === 500)
      this.logger.error(
        'Unhandled API error',
        exception instanceof Error ? exception.stack : undefined,
      );
    host
      .switchToHttp()
      .getResponse<Response>()
      .status(status)
      .json({
        error: {
          code,
          message: Array.isArray(message) ? message.join('; ') : message,
        },
      });
  }
}
@Injectable()
export class EnvelopeInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler) {
    return next.handle().pipe(
      map((value) => {
        if (
          context
            .switchToHttp()
            .getResponse<Response>()
            .getHeader('content-type')
            ?.toString()
            .includes('text/calendar')
        )
          return value;
        return value &&
          typeof value === 'object' &&
          'data' in value &&
          'meta' in value
          ? value
          : { data: value ?? null };
      }),
    );
  }
}
