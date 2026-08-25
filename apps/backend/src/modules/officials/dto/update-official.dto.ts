import { PartialType } from '@nestjs/swagger';
import { CreateOfficialDto } from './create-official.dto';

export class UpdateOfficialDto extends PartialType(CreateOfficialDto) {}
