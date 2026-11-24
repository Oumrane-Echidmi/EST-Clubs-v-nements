import { ArgumentMetadata, Injectable, PipeTransform } from '@nestjs/common';
import { ApiError } from './http';
@Injectable()
export class RejectNullBodyPipe implements PipeTransform {
  transform(value: unknown, metadata: ArgumentMetadata) {
    if (metadata.type === 'body' && value && typeof value === 'object') {
      for (const field of Object.values(value))
        if (field === null)
          throw new ApiError(
            'VALIDATION_ERROR',
            'Omit optional fields instead of sending null',
          );
    }
    return value;
  }
}
